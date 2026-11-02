# frozen_string_literal: true

module Maintenance
  class BackfillReimbursementReportPayoutMethodsTask < MaintenanceTasks::Task
    def collection
      # Exclude reports that have already paid out (reimbursed, reversed): they
      # may have used a payout method the user has since changed, so associating
      # their current default would mislabel them. Every other state hasn't paid
      # out, so the current default is the method they'd be reimbursed through,
      # matching how the payout resolved the method before it was set on the
      # report.
      Reimbursement::Report
        .where(legal_entity_payout_method_id: nil)
        .where.not(aasm_state: [:reimbursed, :reversed])
    end

    def process(report)
      payout_method = report.user&.default_payout_method
      return unless payout_method

      report.update!(legal_entity_payout_method: payout_method)
    end

  end
end
