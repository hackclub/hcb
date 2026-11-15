class AddAssigneeToOrganizerPositionDeletionRequest < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_reference :organizer_position_deletion_requests, :assignee, index: {algorithm: :concurrently}
  end
end
