# frozen_string_literal: true

class ValidateNullCheckConstraintOnGSuiteAccountsAddress < ActiveRecord::Migration[8.0]
  def up
    validate_check_constraint(:g_suite_accounts, name: "g_suite_accounts_address_null")
    change_column_null(:g_suite_accounts, :address, false)
    remove_check_constraint(:g_suite_accounts, name: "g_suite_accounts_address_null")
  end

  def down
    add_check_constraint(
      :g_suite_accounts,
      "address IS NOT NULL",
      name: "g_suite_accounts_address_null",
      validate: false
    )
    change_column_null(:g_suite_accounts, :address, true)
  end
end
