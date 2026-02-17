class AddSupportMessageAndSupportUrlToCardGrantSetting < ActiveRecord::Migration[8.0]
  def change
    add_column :card_grant_settings, :support_message, :string
    add_column :card_grant_settings, :support_url, :string
  end
end
