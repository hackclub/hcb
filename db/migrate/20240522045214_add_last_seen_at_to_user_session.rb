class AddLastSeenAtToUserSession < ActiveRecord::Migration[7.1]
  def change
    add_column :user_sessions, :last_seen_at, :datetime
  end
end
