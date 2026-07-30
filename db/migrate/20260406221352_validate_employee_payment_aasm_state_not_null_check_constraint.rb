class ValidateEmployeePaymentAasmStateNotNullCheckConstraint < ActiveRecord::Migration[8.0]
  def up
    validate_check_constraint :employee_payments, name: "employee_payments_aasm_state_null"
    change_column_null :employee_payments, :aasm_state, false
    remove_check_constraint :employee_payments, name: "employee_payments_aasm_state_null"
  end

  def down
    add_check_constraint :employee_payments, "aasm_state IS NOT NULL", name: "employee_payments_aasm_state_null", validate: false
    change_column_null :employee_payments, :aasm_state, true
  end
end
