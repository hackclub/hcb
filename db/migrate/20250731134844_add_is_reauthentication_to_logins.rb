# frozen_string_literal: true

class AddIsReauthenticationToLogins < ActiveRecord::Migration[7.2]
  def change
    add_column( :logins, :is_reauthentication, :boolean, default: false, null: false)
  end
end
