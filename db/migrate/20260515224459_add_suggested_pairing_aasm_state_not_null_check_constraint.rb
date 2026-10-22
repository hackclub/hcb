class AddSuggestedPairingAasmStateNotNullCheckConstraint < ActiveRecord::Migration[8.0]
  def change
    add_check_constraint :suggested_pairings, "aasm_state IS NOT NULL", name: "suggested_pairings_aasm_state_null", validate: false
  end
end
