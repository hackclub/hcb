class AddRefreshTokenEncryption < ActiveRecord::Migration[8.0]
  def change
    add_column :api_tokens, :refresh_token_ciphertext, :text
  end
end
