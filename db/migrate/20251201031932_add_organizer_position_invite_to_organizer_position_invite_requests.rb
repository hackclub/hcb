class AddOrganizerPositionInviteToOrganizerPositionInviteRequests < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_reference :organizer_position_invite_requests, :organizer_position_invite, null: true, index: {algorithm: :concurrently}
  end
end
