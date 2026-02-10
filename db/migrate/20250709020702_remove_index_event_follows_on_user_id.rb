class RemoveIndexEventFollowsOnUserId < ActiveRecord::Migration[7.2]
  def change
    remove_index :event_follows, column: :user_id, name: "index_event_follows_on_user_id"
  end
end
