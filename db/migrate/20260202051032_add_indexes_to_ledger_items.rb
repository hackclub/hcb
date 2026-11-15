class AddIndexesToLedgerItems < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_index :ledger_items, :date, algorithm: :concurrently
    add_index :ledger_items, :amount_cents, algorithm: :concurrently
  end
end
