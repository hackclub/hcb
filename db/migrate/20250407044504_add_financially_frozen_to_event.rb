class AddFinanciallyFrozenToEvent < ActiveRecord::Migration[7.2]
  def change
    add_column :events, :finanically_frozen, :boolean, null: false, default: false
  end
end
