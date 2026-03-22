# frozen_string_literal: true

class AddRefreshTokenEncryption < ActiveRecord::Migration[8.0]
  def change
    add_column :api_tokens, :refresh_token_ciphertext, :text
    add_column :api_tokens, :refresh_token_bidx, :text
    add_index :api_tokens, :refresh_token_bidx, unique: true
  end
end
