# frozen_string_literal: true

class RemoveRefreshTokenFromApiTokens < ActiveRecord::Migration[8.0]
  def change
    # The plaintext `refresh_token` column was superseded by the encrypted
    # `refresh_token_ciphertext` column and is already ignored by ApiToken
    # (self.ignored_columns). Drop the dead column.
    safety_assured do
      remove_column :api_tokens, :refresh_token, :string
    end
  end

end
