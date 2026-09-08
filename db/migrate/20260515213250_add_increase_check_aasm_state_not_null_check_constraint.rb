class AddIncreaseCheckAasmStateNotNullCheckConstraint < ActiveRecord::Migration[8.0]
  def change
    add_check_constraint :increase_checks, "aasm_state IS NOT NULL", name: "increase_checks_aasm_state_null", validate: false
  end
end
