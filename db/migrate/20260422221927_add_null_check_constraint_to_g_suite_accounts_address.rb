# frozen_string_literal: true

class AddNullCheckConstraintToGSuiteAccountsAddress < ActiveRecord::Migration[7.2]
  def change
    add_check_constraint(
      :g_suite_accounts,
      "address IS NOT NULL",
      name: "g_suite_accounts_address_not_null",
      validate: false
    )
  end
end
