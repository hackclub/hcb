class AddReimbursementReportAasmStateNotNullCheckConstraint < ActiveRecord::Migration[8.0]
  def change
    add_check_constraint :reimbursement_reports, "aasm_state IS NOT NULL", name: "reimbursement_reports_aasm_state_null", validate: false
  end
end
