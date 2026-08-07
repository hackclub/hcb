class ValidateMakeTimestampsNotNullOnCardGrantSettings < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    validate_check_constraint :card_grant_settings, name: "card_grant_settings_created_at_null"
    change_column_null :card_grant_settings, :created_at, false
    remove_check_constraint :card_grant_settings, name: "card_grant_settings_created_at_null"

    validate_check_constraint :card_grant_settings, name: "card_grant_settings_updated_at_null"
    change_column_null :card_grant_settings, :updated_at, false
    remove_check_constraint :card_grant_settings, name: "card_grant_settings_updated_at_null"
  end

  def down
    add_check_constraint :card_grant_settings, "created_at IS NOT NULL", name: "card_grant_settings_created_at_null", validate: false
    change_column_null :card_grant_settings, :created_at, true

    add_check_constraint :card_grant_settings, "updated_at IS NOT NULL", name: "card_grant_settings_updated_at_null", validate: false
    change_column_null :card_grant_settings, :updated_at, true
  end
end
