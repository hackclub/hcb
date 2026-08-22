class AddReceiptCountToLedgerItems < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_column :ledger_items, :receipt_count, :integer, default: 0, null: false
    add_index :ledger_items, :id, name: "index_ledger_items_on_receipt_missing", where: "receipt_required AND marked_no_or_lost_receipt_at IS NULL AND receipt_count = 0", algorithm: :concurrently
  end
end
