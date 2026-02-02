class AddLedgerItemIdToHcbCode < ActiveRecord::Migration[8.0]
  def change
    add_column :hcb_codes, :ledger_item_id, :bigint
  end
end
