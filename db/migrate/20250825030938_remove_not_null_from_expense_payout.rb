class RemoveNotNullFromExpensePayout < ActiveRecord::Migration[7.2]
  def change
    change_column_null(:reimbursement_expense_payouts, :reimbursement_expenses_id, true)
  end
end
