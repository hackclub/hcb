class AddCurrencyToWire < ActiveRecord::Migration[7.1]
  def change
    add_column :wires, :currency, :string, null: false, default: "USD"
  end
end
