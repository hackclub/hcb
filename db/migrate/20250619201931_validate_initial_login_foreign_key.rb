# frozen_string_literal: true

class ValidateInitialLoginForeignKey < ActiveRecord::Migration[7.2]
  def change
    validate_foreign_key(:logins, column: :initial_login_id)
  end
end
