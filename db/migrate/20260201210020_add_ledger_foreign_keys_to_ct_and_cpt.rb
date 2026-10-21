class AddLedgerForeignKeysToCtAndCpt < ActiveRecord::Migration[8.0]
  def change
    add_foreign_key :canonical_pending_transactions, :ledger_items, validate: false
    add_foreign_key :canonical_transactions, :ledger_items, validate: false
  end
end
