class MakeSessionDurationSecondsNullableOnUsers < ActiveRecord::Migration[7.2]
  def change
    change_column_null :users, :session_duration_seconds, true
  end
end
