class ValidateForeignKeyLedgerItemIdOnHcbCode < ActiveRecord::Migration[8.0]
  def change
    validate_foreign_key :hcb_codes, :ledger_items
  end
end
