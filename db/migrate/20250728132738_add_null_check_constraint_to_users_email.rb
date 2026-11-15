# frozen_string_literal: true
#
class AddNullCheckConstraintToUsersEmail < ActiveRecord::Migration[7.2]
    def change
      add_check_constraint(
        :users,
        "email IS NOT NULL",
        name: "users_email_not_null",
        validate: false
      )
    end
end
