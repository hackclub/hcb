class AddMerchantNetworkIdAndMerchantCategoryToCardCharge < ActiveRecord::Migration[8.0]
  def change
    add_column :card_charges, :merchant_network_id, :string
    add_column :card_charges, :merchant_category, :string
  end
end
