class AddCurrencyToReimbursementReports < ActiveRecord::Migration[7.2]
  def change
    add_column :reimbursement_reports, :currency, :string, null: false, default: "USD"
  end
end
