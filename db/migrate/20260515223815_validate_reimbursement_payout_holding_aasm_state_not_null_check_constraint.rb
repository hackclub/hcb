class ValidateReimbursementPayoutHoldingAasmStateNotNullCheckConstraint < ActiveRecord::Migration[8.0]
  def up
    validate_check_constraint :reimbursement_payout_holdings, name: "reimbursement_payout_holdings_aasm_state_null"
    change_column_null :reimbursement_payout_holdings, :aasm_state, false
    remove_check_constraint :reimbursement_payout_holdings, name: "reimbursement_payout_holdings_aasm_state_null"
  end

  def down
    add_check_constraint :reimbursement_payout_holdings, "aasm_state IS NOT NULL", name: "reimbursement_payout_holdings_aasm_state_null", validate: false
    change_column_null :reimbursement_payout_holdings, :aasm_state, true
  end
end
