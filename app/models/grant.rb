# frozen_string_literal: true

# == Schema Information
#
# Table name: grants
#
#  id             :bigint           not null, primary key
#  aasm_state     :string           not null
#  grantable_type :string           not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  event_id       :bigint           not null
#  grantable_id   :bigint           not null
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
# The invitation/acceptance root for a grant. It belongs to whichever fulfillment
# the recipient ends up with: a CardGrant (virtual card) or a Reimbursement::Report.
class Grant < ApplicationRecord
  include Hashid::Rails
  hashid_config salt: ""

  include PublicIdentifiable
  set_public_id_prefix :grt

  has_paper_trail

  belongs_to :event
  belongs_to :user
  belongs_to :sent_by, class_name: "User"
  belongs_to :grantable, polymorphic: true

  include AASM

  aasm do
    state :pending, initial: true
    state :accepted_with_card
    state :accepted_with_reimbursement
    state :canceled
    state :expired

    event :mark_accepted_with_card do
      transitions from: :pending, to: :accepted_with_card
    end

    event :mark_accepted_with_reimbursement do
      transitions from: [:pending, :accepted_with_card], to: :accepted_with_reimbursement
    end

    event :mark_canceled do
      transitions from: [:pending, :accepted_with_card], to: :canceled
    end

    event :mark_expired do
      transitions from: [:pending, :accepted_with_card], to: :expired
    end
  end

  def card_grant
    grantable if grantable.is_a?(CardGrant)
  end

  def reimbursement_report
    grantable if grantable.is_a?(Reimbursement::Report)
  end

end
