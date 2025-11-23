class AddContractToOrganizerPosition < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    add_reference :organizer_positions, :fiscal_sponsorship_contract, index: { algorithm: :concurrently }

    add_foreign_key :organizer_positions,
                    :contracts,
                    column: :fiscal_sponsorship_contract_id,
                    validate: false

    validate_foreign_key :organizer_positions,
                         :contracts

    Contract.all.find_each do |contract|
      # Contractable at this point will only be OrganizerPositionInvite
      if contract.contractable.is_a?(OrganizerPositionInvite)
        op = contract.contractable.organizer_position
        op&.update!(fiscal_sponsorship_contract: contract)
      end
    end
  end

  def down
    remove_reference :organizer_positions, :fiscal_sponsorship_contract, index: { algorithm: :concurrently }
  end
end
