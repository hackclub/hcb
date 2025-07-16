# frozen_string_literal: true

# == Schema Information
#
# Table name: emburse_cards
#
#  id               :bigint           not null, primary key
#  address          :text
#  daily_limit      :bigint
#  deactivated_at   :datetime
#  emburse_state    :string
#  expiration_month :integer
#  expiration_year  :integer
#  full_name        :string
#  is_virtual       :boolean
#  last_four        :string
#  slug             :text
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  emburse_id       :text
#  event_id         :bigint
#  user_id          :bigint
#
# Indexes
#
#  index_emburse_cards_on_event_id  (event_id)
#  index_emburse_cards_on_slug      (slug) UNIQUE
#  index_emburse_cards_on_user_id   (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (event_id => events.id)
#  fk_rails_...  (user_id => users.id)
#
class EmburseCard < ApplicationRecord
  include Hashid::Rails
  extend FriendlyId

  scope :deactivated, -> { where.not(emburse_state: "active") }
  scope :active, -> { where(deactivated_at: nil, emburse_state: "active") }

  paginates_per 100

  friendly_id :slug_text, use: :slugged

  belongs_to :user
  belongs_to :event
  has_one :emburse_card_request
  has_many :emburse_transfers
  has_many :emburse_transactions
  has_many :transactions_missing_receipts, -> { awaiting_receipt }, foreign_key: :emburse_card_id, class_name: "EmburseTransaction"

  # general validations
  validates :full_name,
            :expiration_month,
            :expiration_year,
            :emburse_id,
            presence: true

  # validations for physical
  validates :last_four,
            :address,
            presence: true
  validates :last_four, numericality: { only_integer: true }

  validates :expiration_month, numericality: {
    only_integer: true,
    less_than_or_equal_to: 12,
    greater_than_or_equal_to: 1
  }
  validates :expiration_year, numericality: { only_integer: true }
  validate :emburse_id_format

  def emburse_path
    "https://app.emburse.com/cards/#{emburse_id}"
  end

  def department_id
    emburse_obj&.department&.id
  end

  def suspected_subscriptions
    emburse_transactions.group(:merchant_name).having("COUNT(*)>3").count.keys
  end

  # Emburse emburse_cards have three activation states:
  # 1. "unactivated", when emburse_card first ships. Must be activated by user
  #   at emburse.com/activate to be active, cannot be activated by HCB
  # 2. "active", active emburse_card
  # 3. "suspended", deactivated by user and can be activated again thru HCB.
  def status_text
    if requires_activation?
      "Shipping"
    elsif active?
      "Active"
    elsif suspended?
      "Suspended"
    elsif canceled?
      "Canceled"
    end
  end

  def formatted_card_number
    "•••• •••• •••• #{last_four}"
  end

  def hidden_card_number
    "•••• •••• •••• ••••"
  end

  def requires_activation?
    self.emburse_state == "unactivated"
  end

  def active?
    self.emburse_state == "active"
  end

  def suspended?
    self.emburse_state == "suspended"
  end

  def canceled?
    self.emburse_state == "terminated"
  end

  def hcb_codes
    @emburse_transaction_emburse_ids ||= emburse_transactions.pluck(:emburse_id)
    @raw_emburse_transaction_ids ||= RawEmburseTransaction.where(emburse_transaction_id: @emburse_transaction_emburse_ids).pluck(:id)

    @canonical_transactions ||= CanonicalTransaction.emburse_transaction.where(transaction_source_id: @raw_emburse_transaction_ids)
    @canonical_transaction_hcb_codes ||= @canonical_transactions.pluck(:hcb_code)
    @hcb_codes ||= ::HcbCode.where(hcb_code: @canonical_transaction_hcb_codes)
  end

  private

  def emburse_id_format
    emburse_id_regex = /^[a-z0-9]{8}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{12}$/
    unless emburse_id_regex.match? emburse_id
      errors.add(:emburse_id, "is incorrectly formatted")
    end
  end

  def slug_text
    "#{self.full_name} #{self.last_four}"
  end

end
