class AddTeenagerToUser < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :teenager, :boolean
  end
end
