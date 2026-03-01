class MakeTimestampsNotNullOnCardGrantSettings < ActiveRecord::Migration[8.0]
  def change
    add_check_constraint :card_grant_settings, "created_at IS NOT NULL", name: "card_grant_settings_created_at_null", validate: false

    add_check_constraint :card_grant_settings, "updated_at IS NOT NULL", name: "card_grant_settings_updated_at_null", validate: false
  end
end
