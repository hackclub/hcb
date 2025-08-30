class MakeEventIdNotNullOnCardGrantSettings < ActiveRecord::Migration[7.2]
  def change
    add_check_constraint :card_grant_settings, "event_id IS NOT NULL", name: "card_grant_settings_event_id_null", validate: false
  end

end
