# frozen_string_literal: true

class ValidateLegalEntityPayoutMethodFkOnReimbursementReports < ActiveRecord::Migration[8.0]
  def change
    validate_foreign_key :reimbursement_reports, :legal_entity_payout_methods
  end

end
