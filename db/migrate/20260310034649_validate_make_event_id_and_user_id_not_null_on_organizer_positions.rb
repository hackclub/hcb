class ValidateMakeEventIdAndUserIdNotNullOnOrganizerPositions < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    validate_check_constraint :organizer_positions, name: "organizer_positions_event_id_null"
    change_column_null :organizer_positions, :event_id, false
    remove_check_constraint :organizer_positions, name: "organizer_positions_event_id_null"

    validate_check_constraint :organizer_positions, name: "organizer_positions_user_id_null"
    change_column_null :organizer_positions, :user_id, false
    remove_check_constraint :organizer_positions, name: "organizer_positions_user_id_null"
  end

  def down
    add_check_constraint :organizer_positions, "created_at IS NOT NULL", name: "organizer_positions_event_id_null", validate: false
    change_column_null :organizer_positions, :event_id, true

    add_check_constraint :organizer_positions, "updated_at IS NOT NULL", name: "organizer_positions_user_id_null", validate: false
    change_column_null :organizer_positions, :user_id, true
  end
end
