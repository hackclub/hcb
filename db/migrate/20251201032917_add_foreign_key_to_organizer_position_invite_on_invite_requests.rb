class AddForeignKeyToOrganizerPositionInviteOnInviteRequests < ActiveRecord::Migration[8.0]
  def change
    add_foreign_key :organizer_position_invite_requests, :organizer_position_invites, column: :organizer_position_invite_id, validate: false
  end
end
