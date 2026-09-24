class ValidateWiseTransferAasmStateNotNullCheckConstraint < ActiveRecord::Migration[8.0]
  def up
    validate_check_constraint :wise_transfers, name: "wise_transfers_aasm_state_null"
    change_column_null :wise_transfers, :aasm_state, false
    remove_check_constraint :wise_transfers, name: "wise_transfers_aasm_state_null"
  end

  def down
    add_check_constraint :wise_transfers, "aasm_state IS NOT NULL", name: "wise_transfers_aasm_state_null", validate: false
    change_column_null :wise_transfers, :aasm_state, true
  end
end
