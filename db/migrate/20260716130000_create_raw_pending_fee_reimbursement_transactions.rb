class CreateRawPendingFeeReimbursementTransactions < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    create_table :raw_pending_fee_reimbursement_transactions do |t|
      t.integer :amount_cents
      t.date :date_posted
      t.references :fee_reimbursement, null: false, foreign_key: true, index: { name: "index_rp_fee_reimbursement_txs_on_fee_reimbursement_id" }

      t.timestamps
    end

    add_reference :canonical_pending_transactions, :raw_pending_fee_reimbursement_transaction, null: true, index: { name: "index_cpts_on_raw_pending_fee_reimbursement_tx_id", algorithm: :concurrently }
  end
end
