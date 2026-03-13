class AddRefreshTokenEncryption < ActiveRecord::Migration[8.0]
  def change
    add_column :refresh_token_ciphertext
  end
end
