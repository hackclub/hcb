# frozen_string_literal: true

module Maintenance
  class BackfillReimbursementReportPayoutMethodsTask < MaintenanceTasks::Task
    def collection
      Reimbursement::Report.where(legal_entity_payout_method_id: nil)
    end

    def process(report)
      payout_method = report.user&.default_payout_method
      return unless payout_method

      report.update(legal_entity_payout_method: payout_method)
    end

  end
end
