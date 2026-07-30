class AddBankFeeAasmStateNotNullCheckConstraint < ActiveRecord::Migration[8.0]
  def change
    add_check_constraint :bank_fees, "aasm_state IS NOT NULL", name: "bank_fees_aasm_state_null", validate: false
  end
end
