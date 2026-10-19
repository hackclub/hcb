class ValidateSuggestedPairingAasmStateNotNullCheckConstraint < ActiveRecord::Migration[8.0]
  def up
    validate_check_constraint :suggested_pairings, name: "suggested_pairings_aasm_state_null"
    change_column_null :suggested_pairings, :aasm_state, false
    remove_check_constraint :suggested_pairings, name: "suggested_pairings_aasm_state_null"
  end

  def down
    add_check_constraint :suggested_pairings, "aasm_state IS NOT NULL", name: "suggested_pairings_aasm_state_null", validate: false
    change_column_null :suggested_pairings, :aasm_state, true
  end
end
