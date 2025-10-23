class AddTypeAndValueToExpense < ActiveRecord::Migration[7.0]
  def change
    add_column :reimbursement_expenses, :type, :string
    add_column :reimbursement_expenses, :value, :decimal, null: false, default: 0
    reversible do |dir|
      dir.up do
        update "UPDATE reimbursement_expenses SET value=CAST(amount_cents AS float) / 100"
      end
    end
  end
end
