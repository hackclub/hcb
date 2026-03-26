class ValidateAddForeignKeyToOrganizerPositionInviteOnInviteRequests < ActiveRecord::Migration[8.0]
  def change
    validate_foreign_key :organizer_position_invite_requests, :organizer_position_invites
  end
end
