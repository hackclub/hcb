# frozen_string_literal: true

class AddSlugsToTransactions < ActiveRecord::Migration[5.2]
  def change
    add_column :transact_so_ns, :slug, :text
    add_index :transact_so_ns, :slug, unique: true
  end

end
