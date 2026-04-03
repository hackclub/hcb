class AddAssignedAtToReceipts < ActiveRecord::Migration[7.2]
  def change
    add_column :receipts, :assigned_at, :datetime

    # Backfill existing receipts that are already attached to a transaction
    reversible do |dir|
      dir.up do
        execute <<~SQL
          UPDATE receipts SET assigned_at = created_at WHERE receiptable_id IS NOT NULL
        SQL
      end
    end
  end
end
