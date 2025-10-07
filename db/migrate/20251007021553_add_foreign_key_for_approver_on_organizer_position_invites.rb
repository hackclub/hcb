class AddForeignKeyForApproverOnOrganizerPositionInvites < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_foreign_key :organizer_position_invites, :users, column: :approver_id, validate: false, algorithm: :concurrently
    add_index :organizer_position_invites, :approver_id, algorithm: :concurrently
  end
end
