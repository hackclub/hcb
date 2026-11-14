# frozen_string_literal: true

class AddIndexOnLastUsedAtToApiTokens < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :api_tokens, :last_used_at, algorithm: :concurrently
  end

end
