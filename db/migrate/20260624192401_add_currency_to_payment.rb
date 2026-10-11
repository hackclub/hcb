class AddCurrencyToPayment < ActiveRecord::Migration[8.0]
  def change
    add_column :payments, :currency, :string, null: false
  end
end
