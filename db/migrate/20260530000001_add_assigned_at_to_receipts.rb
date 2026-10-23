# frozen_string_literal: true

class AddAssignedAtToReceipts < ActiveRecord::Migration[8.0]
  def change
    add_column :receipts, :assigned_at, :datetime

    reversible do |dir|
      dir.up do
        execute <<~SQL
          UPDATE receipts
          SET assigned_at = created_at
          WHERE receiptable_id IS NOT NULL
            AND assigned_at IS NULL
        SQL
      end
    end
  end
end
