class AddApproverIdAndInviteMethodToOrganizerPositionInvites < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_column :organizer_position_invites, :approver_id, :bigint
    add_column :organizer_position_invites, :invite_method, :string
  end
end
