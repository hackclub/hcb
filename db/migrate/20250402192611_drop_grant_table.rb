class DropGrantTable < ActiveRecord::Migration[7.2]
  def change
    drop_table :grants
  end
end
