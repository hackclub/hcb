class AddReimbursementExpensePayoutAasmStateNotNullCheckConstraint < ActiveRecord::Migration[8.0]
  def change
    add_check_constraint :reimbursement_expense_payouts, "aasm_state IS NOT NULL", name: "reimbursement_expense_payouts_aasm_state_null", validate: false
  end
end
