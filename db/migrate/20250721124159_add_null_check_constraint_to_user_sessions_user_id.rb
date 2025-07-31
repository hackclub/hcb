# frozen_string_literal: true

class AddNullCheckConstraintToUserSessionsUserId < ActiveRecord::Migration[7.2]
  def change
    add_check_constraint(
      :user_sessions,
      "user_id IS NOT NULL",
      name: "user_sessions_user_id_not_null",
      validate: false
    )
  end
end
