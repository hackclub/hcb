class AddForeignKeyLedgerItemIdToHcbCode < ActiveRecord::Migration[8.0]
  def change
    add_foreign_key :hcb_codes, :ledger_items, on_delete: :nullify, validate: false
  end
end
