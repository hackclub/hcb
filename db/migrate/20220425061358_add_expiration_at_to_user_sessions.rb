# frozen_string_literal: true

class AddExpirationAtToUserSessions < ActiveRecord::Migration[6.0]
  def change
    add_column :user_sessions, :expiration_at, :timestamp, null: true

    reversible do |dir|
      dir.up do
        UserSession.unscoped.update_all("expiration_at = created_at + INTERVAL '30 days'")
      end
    end

    safety_assured do
      change_column_null :user_sessions, :expiration_at, false
    end
  end

end
