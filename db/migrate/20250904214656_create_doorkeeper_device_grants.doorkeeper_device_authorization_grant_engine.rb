# frozen_string_literal: true

# This migration comes from doorkeeper_device_authorization_grant_engine (originally 20200629094624)
class CreateDoorkeeperDeviceGrants < ActiveRecord::Migration[7.2]
  def change
    create_table :oauth_device_grants do |t|
      t.references :resource_owner, null: true
      t.references :application, null: false
      t.string :device_code, null: false
      t.string :user_code, null: true
      t.integer :expires_in, null: false
      t.datetime :created_at, null: false
      t.datetime :last_polling_at, null: true
      t.string :scopes, null: false, default: ''
    end

    add_index :oauth_device_grants, :device_code, unique: true
    add_index :oauth_device_grants, :user_code, unique: true

    add_foreign_key(
      :oauth_device_grants,
      :oauth_applications,
      column: :application_id,
      validate: false
    )

    add_foreign_key :oauth_device_grants, :oauth_access_grants, column: :resource_owner_id, validate: false
  end
end
