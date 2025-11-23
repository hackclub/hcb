class AddContractToOrganizerPosition < ActiveRecord::Migration[8.0]
  def up
    add_reference :organizer_positions, :contract, foreign_key: true

    Contract.all.find_each do |contract|
      # Contractable at this point will only be OrganizerPositionInvite
      if contract.contractable.is_a?(OrganizerPositionInvite)
        op = contract.contractable.organizer_position
        op.update!(contract:)
      end
    end
  end

  def down
    remove_reference :organizer_positions, :contract, foreign_key: true
  end
end
