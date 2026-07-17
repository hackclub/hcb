# frozen_string_literal: true

# == Schema Information
#
# Table name: raw_pending_fee_reimbursement_transactions
#
#  id                   :bigint           not null, primary key
#  amount_cents         :integer
#  date_posted          :date
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  fee_reimbursement_id :bigint           not null
#
# Indexes
#
#  index_rp_fee_reimbursement_txs_on_fee_reimbursement_id  (fee_reimbursement_id)
#
# Foreign Keys
#
#  fk_rails_...  (fee_reimbursement_id => fee_reimbursements.id)
#
class RawPendingFeeReimbursementTransaction < ApplicationRecord
  monetize :amount_cents

  has_one :canonical_pending_transaction
  belongs_to :fee_reimbursement

  def date
    date_posted
  end

  # NOTE: the "fee reimburse" wording is load-bearing — it's what
  # TransactionGroupingEngine::Calculate::HcbCode#outgoing_fee_reimbursement?
  # matches on to group this under the weekly HCB-900-<week> code.
  def memo
    "Fee reimbursement ##{fee_reimbursement.id}"
  end

end
