# frozen_string_literal: true

# == Schema Information
#
# Table name: fee_revenues
#
#  id           :bigint           not null, primary key
#  aasm_state   :string           not null
#  amount_cents :integer
#  end          :date
#  start        :date
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
class FeeRevenue < ApplicationRecord
  include AASM
  include HasBookTransfer

  include Hashid::Rails
  hashid_config salt: ""

  include PublicIdentifiable
  set_public_id_prefix :frv

  has_one :ledger_item, as: :linked_object
  has_many :bank_fees

  scope :in_transit_or_pending, -> { where(aasm_state: ["pending", "in_transit"]) }

  include HasHcbCode
  has_hcb_code ::TransactionGroupingEngine::Calculate::HcbCode::FEE_REVENUE_CODE, eager_create: true

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

  def canonical_transaction
    @canonical_transaction ||= CanonicalTransaction.find_by(hcb_code:)
  end

  def canonical_pending_transaction
    @canonical_pending_transaction ||= raw_pending_fee_revenue_transaction&.canonical_pending_transaction
  end

  def raw_pending_fee_revenue_transaction
    @raw_pending_fee_revenue_transaction ||= ::RawPendingFeeRevenueTransaction.find_by(fee_revenue_transaction_id: id.to_s)
  end

end
