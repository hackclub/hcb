class AddConversionRateToReport < ActiveRecord::Migration[7.2]
  def change
    add_column :reimbursement_reports, :conversion_rate, :float, null: false, default: 1
  end
end
