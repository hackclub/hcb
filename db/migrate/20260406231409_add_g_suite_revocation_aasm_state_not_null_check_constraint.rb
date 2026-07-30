class AddGSuiteRevocationAasmStateNotNullCheckConstraint < ActiveRecord::Migration[8.0]
  def change
    add_check_constraint :g_suite_revocations, "aasm_state IS NOT NULL", name: "g_suite_revocations_aasm_state_null", validate: false
  end
end
