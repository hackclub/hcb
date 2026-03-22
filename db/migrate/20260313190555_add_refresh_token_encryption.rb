# frozen_string_literal: true

class AddRefreshTokenEncryption < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    add_column :api_tokens, :refresh_token_ciphertext, :text
    add_column :api_tokens, :refresh_token_bidx, :text
    add_index :api_tokens, :refresh_token_bidx, unique: true, algorithm: :concurrently
  end

  def down
    remove_index :api_tokens, :refresh_token_bidx
    remove_column :api_tokens, :refresh_token_bidx
    remove_column :api_tokens, :refresh_token_ciphertext
  end
end
