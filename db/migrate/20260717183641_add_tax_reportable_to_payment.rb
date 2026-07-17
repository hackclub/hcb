class AddTaxReportableToPayment < ActiveRecord::Migration[8.0]
  def change
    add_column :payments, :tax_reportable, :boolean, null: false, default: true
  end
end
