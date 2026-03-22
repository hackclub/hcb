class AddBannedMerchantsToCardGrants < ActiveRecord::Migration[7.2]
  def change
    add_column :card_grants, :banned_merchants, :string
    add_column :card_grants, :banned_categories, :string
  end
end
