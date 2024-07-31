class AddInitialControlAllowanceAmountCentsToOrganizerPositionInvite < ActiveRecord::Migration[7.1]
  def change
    add_column :organizer_position_invites, :initial_control_allowance_amount_cents, :integer
  end
end
