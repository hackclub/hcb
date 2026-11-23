class AddRequiresTaxFormToPayment < ActiveRecord::Migration[8.1]
  def change
    add_column :payments, :requires_tax_form, :boolean, null: false, default: true
  end
end
