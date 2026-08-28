class MakeUserNullableOnUserSession < ActiveRecord::Migration[8.0]
  def change
    change_column_null :user_sessions, :user_id, true
  end
end
