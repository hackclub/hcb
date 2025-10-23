class AddExtractedFeaturesToReceipts < ActiveRecord::Migration[7.0]
  def change
    add_column :receipts, :suggested_memo, :string

    add_column :receipts, :extracted_card_last4_ciphertext, :text
    add_column :receipts, :extracted_subtotal_amount_cents, :integer
    add_column :receipts, :extracted_total_amount_cents, :integer
    add_column :receipts, :extracted_date, :datetime
    add_column :receipts, :extracted_merchant_name, :string
    add_column :receipts, :extracted_merchant_url, :string
    add_column :receipts, :extracted_merchant_zip_code, :string

    add_column :receipts, :data_extracted, :boolean, null: false, default: false
  end
end
