# frozen_string_literal: true

class AddAssignedAtToReceipts < ActiveRecord::Migration[8.0]
  def change
    add_column :receipts, :assigned_at, :datetime
  end
end
