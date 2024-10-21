class AddReimbursementPayoutHoldingToCanonicalPendingTransactions < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!
  
  def change
    # The generated index name is too long, thus we need to specify a shorter
    # index name
    add_reference :canonical_pending_transactions, :reimbursement_payout_holding,
                  index: { algorithm: :concurrently, name: "index_canonical_pending_txs_on_reimbursement_payout_holding_id" }
  end
end
