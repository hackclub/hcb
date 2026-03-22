class MakeEventIdAndUserIdNotNullOnOrganizerPositions < ActiveRecord::Migration[8.0]
  def change
    add_check_constraint :organizer_positions, "event_id IS NOT NULL", name: "organizer_positions_event_id_null", validate: false

    add_check_constraint :organizer_positions, "user_id IS NOT NULL", name: "organizer_positions_user_id_null", validate: false
  end
end
