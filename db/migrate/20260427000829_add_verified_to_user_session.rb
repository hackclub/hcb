class AddVerifiedToUserSession < ActiveRecord::Migration[8.0]
  def change
    add_column :user_sessions, :verified, :boolean, default: true, null: false
    change_column_default :user_sessions, :verified, from: true, to: false
  end
end
