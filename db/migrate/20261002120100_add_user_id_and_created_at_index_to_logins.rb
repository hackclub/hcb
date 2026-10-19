# frozen_string_literal: true

class AddUserIdAndCreatedAtIndexToLogins < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :logins, [:user_id, :created_at], algorithm: :concurrently
  end

end
