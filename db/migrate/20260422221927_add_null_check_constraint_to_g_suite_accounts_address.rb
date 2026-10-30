# frozen_string_literal: true

class AddNullCheckConstraintToGSuiteAccountsAddress < ActiveRecord::Migration[8.0]
  def change
    add_check_constraint(
      :g_suite_accounts,
      "address IS NOT NULL",
      name: "g_suite_accounts_address_null",
      validate: false
    )
  end
end
