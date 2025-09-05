class AddPeacefullyExpiredToUserSession < ActiveRecord::Migration[7.2]
  def change
    add_column :user_sessions, :peacefully_expired, :boolean, default: false
  end
end
