class ValidateAddForeignKeyForApproverOnOrganizerPositionInvites < ActiveRecord::Migration[7.2]
  def change
    validate_foreign_key :organizer_position_invites, :users
  end
end
