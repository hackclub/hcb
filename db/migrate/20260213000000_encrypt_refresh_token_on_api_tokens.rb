# frozen_string_literal: true

class EncryptRefreshTokenOnApiTokens < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  # Used to read the plain-text refresh_token column before the column is dropped.
  # ApiToken itself overrides the refresh_token accessor via has_encrypted, so we
  # need this lightweight proxy to read the raw DB value during backfill.
  class PlainApiToken < ActiveRecord::Base
    self.table_name = "api_tokens"
  end

  def up
    safety_assured do
      add_column :api_tokens, :refresh_token_ciphertext, :text
      add_column :api_tokens, :refresh_token_bidx, :string
    end

    ApiToken.reset_column_information

    # Backfill: encrypt existing plain-text refresh tokens.
    PlainApiToken.where.not(refresh_token: nil).find_each do |plain|
      ApiToken.find(plain.id).tap do |record|
        record.refresh_token = plain.refresh_token
        record.save!(validate: false)
      end
    end

    add_index :api_tokens, :refresh_token_bidx, unique: true, algorithm: :concurrently

    safety_assured do
      remove_column :api_tokens, :refresh_token
    end
  end

  def down
    safety_assured do
      add_column :api_tokens, :refresh_token, :string
    end

    ApiToken.reset_column_information
    PlainApiToken.reset_column_information

    # Restore: decrypt back to plain text.
    ApiToken.where.not(refresh_token: nil).find_each do |record|
      PlainApiToken.where(id: record.id).update_all(refresh_token: record.refresh_token)
    end

    remove_index :api_tokens, :refresh_token_bidx, algorithm: :concurrently, if_exists: true

    safety_assured do
      remove_column :api_tokens, :refresh_token_ciphertext
      remove_column :api_tokens, :refresh_token_bidx
    end
  end
end
