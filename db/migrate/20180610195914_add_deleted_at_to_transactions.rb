# frozen_string_literal: true

class AddDeletedAtToTransactions < ActiveRecord::Migration[5.2]
  def change
    add_column :transact_so_ns, :deleted_at, :datetime
    add_index :transact_so_ns, :deleted_at
  end

end
