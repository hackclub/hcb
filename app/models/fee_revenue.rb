# frozen_string_literal: true

# == Schema Information
#
# Table name: fee_revenues
#
#  id           :bigint           not null, primary key
#  aasm_state   :string
#  amount_cents :integer
#  end          :date
#  start        :date
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
class FeeRevenue < ApplicationRecord
  include AASM
  include HasBookTransfer

  include PublicIdentifiable
  set_public_id_prefix :frv

  has_many :bank_fees

  # Eagerly create HcbCode object
  after_create :local_hcb_code

  aasm do
    state :pending, initial: true
    state :in_transit
    state :settled

    event :mark_in_transit do
      transitions from: :pending, to: :in_transit
    end

    event :mark_settled do
      transitions from: :in_transit, to: :settled
    end
  end

  def hcb_code
    "HCB-#{::TransactionGroupingEngine::Calculate::HcbCode::FEE_REVENUE_CODE}-#{id}"
  end

  def local_hcb_code
    @local_hcb_code ||= HcbCode.find_or_create_by(hcb_code:)
  end

  def canonical_transaction
    @canonical_transaction ||= CanonicalTransaction.find_by(hcb_code:)
  end

end
