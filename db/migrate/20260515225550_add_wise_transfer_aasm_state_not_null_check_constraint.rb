class AddWiseTransferAasmStateNotNullCheckConstraint < ActiveRecord::Migration[8.0]
  def change
    add_check_constraint :wise_transfers, "aasm_state IS NOT NULL", name: "wise_transfers_aasm_state_null", validate: false
  end
end
