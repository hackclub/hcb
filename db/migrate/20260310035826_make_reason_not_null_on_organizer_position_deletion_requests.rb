class MakeReasonNotNullOnOrganizerPositionDeletionRequests < ActiveRecord::Migration[8.0]
  def change
    add_check_constraint :organizer_position_deletion_requests, "reason IS NOT NULL", name: "organizer_position_deletion_requests_reason_null", validate: false
  end
end
