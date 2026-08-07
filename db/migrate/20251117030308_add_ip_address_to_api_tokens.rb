# frozen_string_literal: true

class AddIpAddressToApiTokens < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    safety_assured do
      add_column :api_tokens, :ip_address, :inet
      add_index :api_tokens, :ip_address, algorithm: :concurrently
    end
  end
end
