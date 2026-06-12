class ValidateLedgerForeignKeysOnCtAndCpt < ActiveRecord::Migration[8.0]
  def change
    validate_foreign_key :canonical_pending_transactions, :ledger_items
    validate_foreign_key :canonical_transactions, :ledger_items
  end
end
