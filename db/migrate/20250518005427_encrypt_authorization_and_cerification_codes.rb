class EncryptAuthorizationAndCerificationCodes < ActiveRecord::Migration[7.2]
  def change
    add_column :user_email_updates, :authorization_token_ciphertext, :text
    add_column :user_email_updates, :verification_token_ciphertext, :text
  end
end
