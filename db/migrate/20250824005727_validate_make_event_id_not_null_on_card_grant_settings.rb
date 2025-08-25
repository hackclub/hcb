class ValidateMakeEventIdNotNullOnCardGrantSettings < ActiveRecord::Migration[7.2]
  def up
    validate_check_constraint :card_grant_settings, name: "card_grant_settings_event_id_null"
    change_column_null :card_grant_settings, :event_id, false
    remove_check_constraint :card_grant_settings, name: "card_grant_settings_event_id_null"
  end

  def down
    add_check_constraint :card_grant_settings, "event_id IS NOT NULL", name: "card_grant_settings_event_id_null", validate: false
    change_column_null :card_grant_settings, :event_id, true
  end

end
