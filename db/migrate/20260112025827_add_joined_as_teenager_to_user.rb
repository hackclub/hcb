class AddJoinedAsTeenagerToUser < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :joined_as_teenager, :boolean
  end
end
