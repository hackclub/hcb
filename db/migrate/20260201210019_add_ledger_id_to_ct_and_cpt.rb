class AddLedgerIdToCtAndCpt < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_reference :canonical_pending_transactions, :ledger_item, null: true, index: { algorithm: :concurrently }
    add_reference :canonical_transactions, :ledger_item, null: true, index: { algorithm: :concurrently }
  end
end
