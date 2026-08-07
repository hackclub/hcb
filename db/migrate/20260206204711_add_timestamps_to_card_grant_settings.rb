class AddTimestampsToCardGrantSettings < ActiveRecord::Migration[8.0]
  def change
    add_timestamps :card_grant_settings, null: true
  end
end
