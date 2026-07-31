class AddMemoColumnsToLedgerItems < ActiveRecord::Migration[8.0]
  def change
    add_column :ledger_items, :system_memo, :text
    add_column :ledger_items, :custom_memo, :text
  end
end
