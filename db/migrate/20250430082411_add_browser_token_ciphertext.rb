class AddBrowserTokenCiphertext < ActiveRecord::Migration[7.2]
  def change
    add_column :logins, :browser_token_ciphertext, :text
  end
end
