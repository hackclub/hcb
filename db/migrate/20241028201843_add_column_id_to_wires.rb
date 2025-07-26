class AddColumnIdToWires < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!
  
  def change
    add_column :wires, :column_id, :text
    add_index :wires, :column_id, unique: true, algorithm: :concurrently
  end
end
