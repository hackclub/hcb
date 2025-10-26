# frozen_string_literal: true

class BackfillIsReauthenticationOnLogins < ActiveRecord::Migration[7.2]
  def up
    # This impacts few enough records in production that a more batched approach
    # would be overkill.
    safety_assured do
      execute <<~SQL
        UPDATE logins
        SET is_reauthentication = true
        WHERE initial_login_id IS NOT NULL
      SQL
    end
  end

  def down; end
end
