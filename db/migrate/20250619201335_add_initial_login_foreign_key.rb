# frozen_string_literal: true

class AddInitialLoginForeignKey < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_foreign_key(
      :logins,
      :logins,
      column: :initial_login_id,
      validate: false,
      index: { algorithm: :concurrently }
    )
  end
end
