class AddSupportSlackUrlToCardGrantSettings < ActiveRecord::Migration[8.0]
  def change
    add_column :card_grant_settings, :support_slack_url, :string
  end
end
