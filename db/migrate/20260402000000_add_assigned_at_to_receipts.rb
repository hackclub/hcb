# frozen_string_literal: true

class AddAssignedAtToReceipts < ActiveRecord::Migration[8.0]
  def up
    add_column :receipts, :assigned_at, :datetime

    execute <<~SQL
      UPDATE receipts
      SET assigned_at = created_at
      WHERE receiptable_id IS NOT NULL
        AND assigned_at IS NULL
    SQL
  end

  def down
    remove_column :receipts, :assigned_at
  end
end
