# frozen_string_literal: true

class AddLastUsedAtToApiTokens < ActiveRecord::Migration[8.1]
  def change
    add_column :api_tokens, :last_used_at, :datetime
  end

end
