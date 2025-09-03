class AddWireToCanonicalPendingTransaction < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    add_reference :canonical_pending_transactions, :wire, null: true, index: { algorithm: :concurrently }
  end
end
