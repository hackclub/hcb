class RemoveSessionDurationSecondsFromUser < ActiveRecord::Migration[7.2]
  def up
    safety_assured { remove_column :users, :session_duration_seconds }
  end

  def down
    add_column :users, :session_duration_seconds, :boolean
  end
end
