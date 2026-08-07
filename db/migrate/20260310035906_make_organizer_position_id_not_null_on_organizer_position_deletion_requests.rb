class MakeOrganizerPositionIdNotNullOnOrganizerPositionDeletionRequests < ActiveRecord::Migration[8.0]
  def change
    add_check_constraint :organizer_position_deletion_requests, "organizer_position_id IS NOT NULL", name: "organizer_position_deletion_requests_organizer_position_id_null", validate: false
  end
end
