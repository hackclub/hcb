# frozen_string_literal: true

class DropRefreshTokenFromApiTokens < ActiveRecord::Migration[8.1]
  def change
    safety_assured { remove_column :api_tokens, :refresh_token, :string }
  end

end
