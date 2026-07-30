class AddDisbursementAasmStateNotNullCheckConstraint < ActiveRecord::Migration[8.0]
  def change
    add_check_constraint :disbursements, "aasm_state IS NOT NULL", name: "disbursements_aasm_state_null", validate: false
  end
end
