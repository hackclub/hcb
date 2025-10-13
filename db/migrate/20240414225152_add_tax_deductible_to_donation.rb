class AddTaxDeductibleToDonation < ActiveRecord::Migration[7.0]
  def change
    add_column :donations, :tax_deductible, :boolean, null: false, default: true
    add_column :recurring_donations, :tax_deductible, :boolean, null: false, default: true
  end
end
