# frozen_string_literal: true

# == Schema Information
#
# Table name: payments
#
#  id              :bigint           not null, primary key
#  aasm_state      :string           not null
#  amount_cents    :integer          not null
#  failed_at       :datetime
#  payout_type     :string
#  purpose         :string           not null
#  rejected_at     :datetime
#  sent_at         :datetime
#  successful_at   :datetime
#  under_review_at :datetime
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  payout_id       :bigint
#
# Indexes
#
#  index_payments_on_payout  (payout_type,payout_id)
#
class Payment < ApplicationRecord
  include AASM
  has_paper_trail

  belongs_to :payout, polymorphic: true, optional: true

  monetize :amount_cents

  aasm timestamps: true do
    state :submitted, initial: true
    state :pending_legal_entity
    state :pending_payment_method
    state :under_review
    state :sent
    state :rejected
    state :failed
    state :successful
  end

end
