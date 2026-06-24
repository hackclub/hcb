class AddCheckAasmStateNotNullCheckConstraint < ActiveRecord::Migration[8.0]
  def change
    add_check_constraint :checks, "aasm_state IS NOT NULL", name: "checks_aasm_state_null", validate: false
  end
end
