# frozen_string_literal: true

class ValidateNullCheckConstraintOnUsersEmail < ActiveRecord::Migration[7.2]
  def up
    validate_check_constraint(:users, name: "users_email_not_null")
    change_column_null(:users, :email, false)
    remove_check_constraint(:users, name: "users_email_not_null")
  end

  def down
    add_check_constraint(
      :users,
      "email IS NOT NULL",
      name: "users_email_not_null",
      validate: false
    )
    change_column_null(:users, :email, true)
  end
end
