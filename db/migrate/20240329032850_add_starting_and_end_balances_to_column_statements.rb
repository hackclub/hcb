class AddStartingAndEndBalancesToColumnStatements < ActiveRecord::Migration[7.0]
  def change
    add_column :column_statements, :starting_balance, :integer
    add_column :column_statements, :closing_balance, :integer
  end
end
