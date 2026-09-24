class AddTransactionCountsToLedgerItems < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_column :ledger_items, :ct_count, :integer, default: 0, null: false
    add_column :ledger_items, :cpt_count, :integer, default: 0, null: false
  end
end
