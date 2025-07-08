class RemoveUserIdIndexFromRaffles < ActiveRecord::Migration[7.2]
  def change
    remove_index :raffles, name: "index_raffles_on_user_id", column: :user_id
  end
end
