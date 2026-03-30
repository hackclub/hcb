class AddContractPartyAasmStateNotNullCheckConstraint < ActiveRecord::Migration[8.0]
  def change
    add_check_constraint :contract_parties, "aasm_state IS NOT NULL", name: "contract_parties_aasm_state_null", validate: false
  end
end
