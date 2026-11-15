class AddAchTransferAasmStateNotNullCheckConstraint < ActiveRecord::Migration[8.0]
  def change
    add_check_constraint :ach_transfers, "aasm_state IS NOT NULL", name: "ach_transfers_aasm_state_null", validate: false
  end
end
