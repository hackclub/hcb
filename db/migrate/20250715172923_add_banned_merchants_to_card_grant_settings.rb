class AddBannedMerchantsToCardGrantSettings < ActiveRecord::Migration[7.2]
  def change
    add_column :card_grant_settings, :banned_merchants, :string
    add_column :card_grant_settings, :banned_categories, :string
  end
end
