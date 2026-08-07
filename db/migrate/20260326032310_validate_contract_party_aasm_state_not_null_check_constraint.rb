class ValidateContractPartyAasmStateNotNullCheckConstraint < ActiveRecord::Migration[8.0]
  def up
    validate_check_constraint :contract_parties, name: "contract_parties_aasm_state_null"
    change_column_null :contract_parties, :aasm_state, false
    remove_check_constraint :contract_parties, name: "contract_parties_aasm_state_null"
  end

  def down
    add_check_constraint :contract_parties, "aasm_state IS NOT NULL", name: "contract_parties_aasm_state_null", validate: false
    change_column_null :contract_parties, :aasm_state, true
  end
end
