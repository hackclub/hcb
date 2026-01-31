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
  end

  def down
    remove_reference :organizer_positions, :fiscal_sponsorship_contract, index: { algorithm: :concurrently }
  end
end
