class ValidateReimbursementReportAasmStateNotNullCheckConstraint < ActiveRecord::Migration[8.0]
  def up
    validate_check_constraint :reimbursement_reports, name: "reimbursement_reports_aasm_state_null"
    change_column_null :reimbursement_reports, :aasm_state, false
    remove_check_constraint :reimbursement_reports, name: "reimbursement_reports_aasm_state_null"
  end

  def down
    add_check_constraint :reimbursement_reports, "aasm_state IS NOT NULL", name: "reimbursement_reports_aasm_state_null", validate: false
    change_column_null :reimbursement_reports, :aasm_state, true
  end
end
