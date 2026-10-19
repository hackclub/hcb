# frozen_string_literal: true

# == Schema Information
#
# Table name: card_grant_templates
#
#  id                         :bigint           not null, primary key
#  amount_cents               :integer
#  banned_categories          :string
#  banned_merchants           :string
#  category_lock              :string
#  expiration_days            :integer
#  instructions               :text
#  invite_message             :string
#  keyword_lock               :string
#  merchant_lock              :string
#  name                       :string           not null
#  one_time_use               :boolean          default(FALSE), not null
#  pre_authorization_required :boolean          default(FALSE), not null
#  purpose                    :string
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  created_by_id              :bigint           not null
#  event_id                   :bigint           not null
#
# Indexes
#
#  index_card_grant_templates_on_created_by_id            (created_by_id)
#  index_card_grant_templates_on_event_id_and_lower_name  (event_id, lower((name)::text)) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (created_by_id => users.id)
#  fk_rails_...  (event_id => events.id)
#
class CardGrantTemplate < ApplicationRecord
  include Hashid::Rails

  has_paper_trail

  belongs_to :event
  belongs_to :created_by, class_name: "User"

  serialize :merchant_lock, coder: CommaSeparatedCoder
  serialize :category_lock, coder: CommaSeparatedCoder
  serialize :banned_merchants, coder: CommaSeparatedCoder
  serialize :banned_categories, coder: CommaSeparatedCoder

  MAXIMUM_NAME_LENGTH = 50

  # Settings copied between a template and a card grant. Notably, this excludes
  # the recipient's email and the expiration date (stored as a relative number
  # of days so templates don't go stale).
  GRANT_ATTRIBUTES = %i[amount_cents purpose instructions invite_message one_time_use pre_authorization_required merchant_lock category_lock keyword_lock banned_merchants banned_categories].freeze

  normalizes :name, with: ->(name) { name.strip }
  normalizes :keyword_lock, with: ->(keyword_lock) { keyword_lock.strip.presence }

  validates :name, presence: true, length: { maximum: MAXIMUM_NAME_LENGTH }, uniqueness: { scope: :event_id, case_sensitive: false }
  validates :purpose, length: { maximum: CardGrant::MAXIMUM_PURPOSE_LENGTH }
  validates :amount_cents, numericality: { greater_than: 0, only_integer: true }, integer_column: true, allow_nil: true
  validates :expiration_days, numericality: { greater_than: 0, only_integer: true }, integer_column: true, allow_nil: true
  validates :keyword_lock, regexp: true

  scope :alphabetical, -> { order(Arel.sql("LOWER(name)")) }

  monetize :amount_cents, allow_nil: true

  # Copies this template's settings onto an unsaved card grant.
  def apply_to(card_grant)
    GRANT_ATTRIBUTES.each do |attribute|
      card_grant.public_send(:"#{attribute}=", public_send(attribute))
    end
    card_grant.expiration_at = expiration_days.days.from_now.to_date if expiration_days.present?

    card_grant
  end

  # Copies a card grant's settings (but never its recipient) onto this template.
  def assign_from(card_grant)
    GRANT_ATTRIBUTES.each do |attribute|
      public_send(:"#{attribute}=", card_grant.public_send(attribute))
    end
    self.keyword_lock = card_grant.read_attribute(:keyword_lock) # skip CardGrant's fallback to the event's setting

    self.expiration_days = if card_grant.expiration_at.present? && card_grant.expiration_at.to_date != card_grant.default_expiration_at.to_date
                             (card_grant.expiration_at.to_date - Date.current).to_i
                           end

    self
  end

end
