class ValidateMakeReasonNotNullOnOrganizerPositionDeletionRequests < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    validate_check_constraint :organizer_position_deletion_requests, name: "organizer_position_deletion_requests_reason_null"
    change_column_null :organizer_position_deletion_requests, :reason, false
    remove_check_constraint :organizer_position_deletion_requests, name: "organizer_position_deletion_requests_reason_null"
  end

  def down
    add_check_constraint :organizer_position_deletion_requests, "reason IS NOT NULL", name: "organizer_position_deletion_requests_reason_null", validate: false
    change_column_null :organizer_position_deletion_requests, :reason, true
  end
end
