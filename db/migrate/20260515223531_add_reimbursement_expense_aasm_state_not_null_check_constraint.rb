class AddReimbursementExpenseAasmStateNotNullCheckConstraint < ActiveRecord::Migration[8.0]
  def change
    add_check_constraint :reimbursement_expenses, "aasm_state IS NOT NULL", name: "reimbursement_expenses_aasm_state_null", validate: false
  end
end
