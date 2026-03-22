class AddRawPendingColumnTransactionIdToCanonicalPendingTransaction < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_reference :canonical_pending_transactions, :raw_pending_column_transaction, index: { algorithm: :concurrently, name: "index_canonical_pending_txs_on_rpct_id" }
    add_index :canonical_pending_transactions, :raw_pending_column_transaction_id, unique: true, algorithm: :concurrently
  end
end
