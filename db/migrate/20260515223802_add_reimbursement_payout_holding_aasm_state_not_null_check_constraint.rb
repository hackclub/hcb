class AddReimbursementPayoutHoldingAasmStateNotNullCheckConstraint < ActiveRecord::Migration[8.0]
  def change
    add_check_constraint :reimbursement_payout_holdings, "aasm_state IS NOT NULL", name: "reimbursement_payout_holdings_aasm_state_null", validate: false
  end
end
