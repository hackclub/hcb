class AddExtractedFieldsToCardGrantPreAuthorizations < ActiveRecord::Migration[7.2]
  def change
    add_column :card_grant_pre_authorizations, :extracted_product_name, :string
    add_column :card_grant_pre_authorizations, :extracted_product_description, :text
    add_column :card_grant_pre_authorizations, :extracted_product_price_cents, :integer
    add_column :card_grant_pre_authorizations, :extracted_total_price_cents, :integer
    add_column :card_grant_pre_authorizations, :extracted_merchant_name, :string
    add_column :card_grant_pre_authorizations, :extracted_validity_reasoning, :text
    add_column :card_grant_pre_authorizations, :extracted_valid_purchase, :boolean
    add_column :card_grant_pre_authorizations, :extracted_fraud_rating, :integer
  end
end
