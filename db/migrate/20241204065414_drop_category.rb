class DropCategory < ActiveRecord::Migration[7.2]
  def change
    safety_assured { remove_column :events, :category }
  end
end
