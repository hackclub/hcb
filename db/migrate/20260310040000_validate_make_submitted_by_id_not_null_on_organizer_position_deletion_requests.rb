class ValidateMakeSubmittedByIdNotNullOnOrganizerPositionDeletionRequests < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    validate_check_constraint :organizer_position_deletion_requests, name: "organizer_position_deletion_requests_submitted_by_id_null"
    change_column_null :organizer_position_deletion_requests, :submitted_by_id, false
    remove_check_constraint :organizer_position_deletion_requests, name: "organizer_position_deletion_requests_submitted_by_id_null"
  end

  def down
    add_check_constraint :organizer_position_deletion_requests, "submitted_by_id IS NOT NULL", name: "organizer_position_deletion_requests_submitted_by_id_null", validate: false
    change_column_null :organizer_position_deletion_requests, :submitted_by_id, true
  end
end
