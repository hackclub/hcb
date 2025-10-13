class AddExpirationToCardGrantSetting < ActiveRecord::Migration[7.1]
  def change
    add_column :card_grant_settings, :expiration_preference, :integer, null: false, default: 365 # days
  end
end
