class FixedFrozenSpelling < ActiveRecord::Migration[7.2]
  def change
    add_column :events, :financially_frozen, :boolean, null: false, default: false
  end
end
