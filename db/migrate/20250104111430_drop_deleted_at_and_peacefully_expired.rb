class DropDeletedAtAndPeacefullyExpired < ActiveRecord::Migration[7.2]
  def change
    safety_assured do
      remove_column :user_sessions, :deleted_at
      remove_column :user_sessions, :peacefully_expired
    end
  end
end
