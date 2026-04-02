# frozen_string_literal: true

class AddAssignedAtToReceipts < ActiveRecord::Migration[7.2]
  def change
    add_column :receipts, :assigned_at, :datetime
  end
end
