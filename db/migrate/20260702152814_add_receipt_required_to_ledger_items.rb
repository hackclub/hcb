class AddReceiptRequiredToLedgerItems < ActiveRecord::Migration[8.0]
  def change
    add_column :ledger_items, :receipt_required, :boolean
  end
end
