class ValidateGSuiteRevocationAasmStateNotNullCheckConstraint < ActiveRecord::Migration[8.0]
  def up
    validate_check_constraint :g_suite_revocations, name: "g_suite_revocations_aasm_state_null"
    change_column_null :g_suite_revocations, :aasm_state, false
    remove_check_constraint :g_suite_revocations, name: "g_suite_revocations_aasm_state_null"
  end

  def down
    add_check_constraint :g_suite_revocations, "aasm_state IS NOT NULL", name: "g_suite_revocations_aasm_state_null", validate: false
    change_column_null :g_suite_revocations, :aasm_state, true
  end
end
