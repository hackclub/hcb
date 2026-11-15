class AddFeeRevenueAasmStateNotNullCheckConstraint < ActiveRecord::Migration[8.0]
  def change
    add_check_constraint :fee_revenues, "aasm_state IS NOT NULL", name: "fee_revenues_aasm_state_null", validate: false
  end
end
