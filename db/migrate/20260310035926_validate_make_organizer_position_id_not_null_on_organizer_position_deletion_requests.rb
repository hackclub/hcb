class ValidateMakeOrganizerPositionIdNotNullOnOrganizerPositionDeletionRequests < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    validate_check_constraint :organizer_position_deletion_requests, name: "organizer_position_deletion_requests_organizer_position_id_null"
    change_column_null :organizer_position_deletion_requests, :organizer_position_id, false
    remove_check_constraint :organizer_position_deletion_requests, name: "organizer_position_deletion_requests_organizer_position_id_null"
  end

  def down
    add_check_constraint :organizer_position_deletion_requests, "organizer_position_id IS NOT NULL", name: "organizer_position_deletion_requests_organizer_position_id_null", validate: false
    change_column_null :organizer_position_deletion_requests, :organizer_position_id, true
  end
end
