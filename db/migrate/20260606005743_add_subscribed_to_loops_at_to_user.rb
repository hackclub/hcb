class AddSubscribedToLoopsAtToUser < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :subscribed_to_loops_at, :datetime
  end
end
