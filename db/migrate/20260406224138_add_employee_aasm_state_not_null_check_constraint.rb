class AddEmployeeAasmStateNotNullCheckConstraint < ActiveRecord::Migration[8.0]
  def change
    add_check_constraint :employees, "aasm_state IS NOT NULL", name: "employees_aasm_state_null", validate: false
  end
end
