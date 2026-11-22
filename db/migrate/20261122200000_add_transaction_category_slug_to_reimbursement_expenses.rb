# frozen_string_literal: true

class AddTransactionCategorySlugToReimbursementExpenses < ActiveRecord::Migration[8.1]
  def change
    add_column :reimbursement_expenses, :transaction_category_slug, :string
  end

end
