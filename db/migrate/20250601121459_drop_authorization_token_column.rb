class DropAuthorizationTokenColumn < ActiveRecord::Migration[7.2]
  def change
    safety_assured do
      remove_column :user_email_updates, :authorization_token
      remove_column :user_email_updates, :verification_token
    end
  end
end
