class AddWiseTransferToCanonicalPendingTransaction < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_reference :canonical_pending_transactions, :wise_transfer, null: true, index: { algorithm: :concurrently }
  end
end
