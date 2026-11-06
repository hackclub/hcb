# frozen_string_literal: true

class DropRawPendingFeeReimbursementTransactionIdFromCpts < ActiveRecord::Migration[8.1]
  def change
    safety_assured do
      remove_reference :canonical_pending_transactions, :raw_pending_fee_reimbursement_transaction, index: { name: "index_cpts_on_raw_pending_fee_reimbursement_tx_id" }
    end
  end

end
