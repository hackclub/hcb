class MakeSubmittedByIdNotNullOnOrganizerPositionDeletionRequests < ActiveRecord::Migration[8.0]
  def change
    add_check_constraint :organizer_position_deletion_requests, "submitted_by_id IS NOT NULL", name: "organizer_position_deletion_requests_submitted_by_id_null", validate: false
  end
end
