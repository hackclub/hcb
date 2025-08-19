class AddExtractedCurrencyToReceipt < ActiveRecord::Migration[7.2]
  def change
    add_column :receipts, :extracted_currency, :string
  end
end
