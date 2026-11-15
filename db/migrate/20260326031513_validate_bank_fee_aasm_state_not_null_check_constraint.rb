class ValidateBankFeeAasmStateNotNullCheckConstraint < ActiveRecord::Migration[8.0]
  def up
    validate_check_constraint :bank_fees, name: "bank_fees_aasm_state_null"
    change_column_null :bank_fees, :aasm_state, false
    remove_check_constraint :bank_fees, name: "bank_fees_aasm_state_null"
  end

  def down
    add_check_constraint :bank_fees, "aasm_state IS NOT NULL", name: "bank_fees_aasm_state_null", validate: false
    change_column_null :bank_fees, :aasm_state, true
  end
end
