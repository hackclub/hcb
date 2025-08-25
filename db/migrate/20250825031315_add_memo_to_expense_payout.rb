class AddMemoToExpensePayout < ActiveRecord::Migration[7.2]
  def change
    add_column :reimbursement_expense_payouts, :memo, :string
  end
end
