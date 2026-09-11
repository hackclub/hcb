# frozen_string_literal: true

# == Schema Information
#
# Table name: grants
#
#  id             :bigint           not null, primary key
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  event_id       :bigint           not null
#  grantable_id   :bigint           not null
#  grantable_type :string           not null
#  sent_by_id     :bigint           not null
#  user_id        :bigint           not null
#
# Indexes
#
#  index_grants_on_event_id    (event_id)
#  index_grants_on_grantable   (grantable_type,grantable_id) UNIQUE
#  index_grants_on_sent_by_id  (sent_by_id)
#  index_grants_on_user_id     (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (event_id => events.id)
#  fk_rails_...  (sent_by_id => users.id)
#  fk_rails_...  (user_id => users.id)
#
class Grant < ApplicationRecord
  include Hashid::Rails
  hashid_config salt: ""

  has_paper_trail

  include PublicIdentifiable
  set_public_id_prefix :grn

  include HasPaperTrailHelpers

  belongs_to :event
  belongs_to :user
  belongs_to :sent_by, class_name: "User"
  belongs_to :grantable, polymorphic: true

  GRANTABLE_TYPES = ["CardGrant", "Reimbursement::Report"].freeze
  validates :grantable_type, inclusion: { in: GRANTABLE_TYPES }

  STATUSES = %w[pending accepted_with_card accepted_with_reimbursement canceled expired].freeze

  delegate :amount, :amount_cents, :email, :purpose, :expiration_at, :instructions,
           :invite_message, :effective_allow_stripe_card, :effective_allow_reimbursement_report,
           to: :card_grant

  # The CardGrant that holds this grant's invitation data: the grantable itself on
  # the card path, or the originating card grant once accepted as a reimbursement.
  def card_grant
    grantable.is_a?(CardGrant) ? grantable : grantable.card_grant
  end

  def reimbursement_report
    grantable.is_a?(Reimbursement::Report) ? grantable : card_grant.reimbursement_report
  end

  # Derived from the authoritative CardGrant AASM status so there is no second
  # state machine to keep in sync.
  def status
    return "canceled" if card_grant.canceled?
    return "expired" if card_grant.expired?
    return "accepted_with_reimbursement" if card_grant.converted_to_reimbursement?
    return "accepted_with_card" if card_grant.stripe_card_id.present?

    "pending"
  end

  STATUSES.each do |value|
    define_method(:"#{value}?") { status == value }
  end

  def accepted?
    accepted_with_card? || accepted_with_reimbursement?
  end

end
