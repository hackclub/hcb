# frozen_string_literal: true

class ValidateNullCheckConstraintOnUserSessionsUserId < ActiveRecord::Migration[7.2]
  def up
    validate_check_constraint(:user_sessions, name: "user_sessions_user_id_not_null")
    change_column_null(:user_sessions, :user_id, false)
    remove_check_constraint(:user_sessions, name: "user_sessions_user_id_not_null")
  end

  def down
    add_check_constraint(
      :user_sessions,
      "user_id IS NOT NULL",
      name: "user_sessions_user_id_not_null",
      validate: false
    )
    change_column_null(:user_sessions, :user_id, true)
  end
end
