class AddUniqueShortCodeToLedgerItems < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_index :ledger_items, :short_code,
              unique: true,
              algorithm: :concurrently
  end
end
