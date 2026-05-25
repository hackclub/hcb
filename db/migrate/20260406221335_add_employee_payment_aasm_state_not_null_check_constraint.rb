class AddEmployeePaymentAasmStateNotNullCheckConstraint < ActiveRecord::Migration[8.0]
  def change
    add_check_constraint :employee_payments, "aasm_state IS NOT NULL", name: "employee_payments_aasm_state_null", validate: false
  end
end
