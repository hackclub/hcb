class ValidateCheckAasmStateNotNullCheckConstraint < ActiveRecord::Migration[8.0]
  def up
    validate_check_constraint :checks, name: "checks_aasm_state_null"
    change_column_null :checks, :aasm_state, false
    remove_check_constraint :checks, name: "checks_aasm_state_null"
  end

  def down
    add_check_constraint :checks, "aasm_state IS NOT NULL", name: "checks_aasm_state_null", validate: false
    change_column_null :checks, :aasm_state, true
  end
end
