class AddCategoryToReimbursementExpense < ActiveRecord::Migration[7.2]
  def change
    add_column :reimbursement_expenses, :category, :integer
  end
end
