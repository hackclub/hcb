class AddIntendedAtToLedgerItems < ActiveRecord::Migration[8.1]
  def change
    add_column :ledger_items, :intended_at, :datetime
  end
end
