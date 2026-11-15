class AddBlindIndex < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!
  def change
    add_column :user_email_updates, :authorization_token_bidx, :string
    add_index :user_email_updates, :authorization_token_bidx, algorithm: :concurrently
    add_column :user_email_updates, :verification_token_bidx, :string
    add_index :user_email_updates, :verification_token_bidx, algorithm: :concurrently
  end
end
