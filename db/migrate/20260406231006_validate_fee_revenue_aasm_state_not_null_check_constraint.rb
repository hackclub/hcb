class ValidateFeeRevenueAasmStateNotNullCheckConstraint < ActiveRecord::Migration[8.0]
  def up
    validate_check_constraint :fee_revenues, name: "fee_revenues_aasm_state_null"
    change_column_null :fee_revenues, :aasm_state, false
    remove_check_constraint :fee_revenues, name: "fee_revenues_aasm_state_null"
  end

  def down
    add_check_constraint :fee_revenues, "aasm_state IS NOT NULL", name: "fee_revenues_aasm_state_null", validate: false
    change_column_null :fee_revenues, :aasm_state, true
  end
end
