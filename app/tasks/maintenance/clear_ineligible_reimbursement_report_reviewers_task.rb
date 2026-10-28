# frozen_string_literal: true

module Maintenance
  # One-time cleanup: reports used to keep their assigned reviewer when moved
  # to another organization, leaving reviewers who aren't managers of the
  # report's organization. Only pending reports are touched so the reviewer on
  # already-processed reports stays as a record. Run once after deploying.
  class ClearIneligibleReimbursementReportReviewersTask < MaintenanceTasks::Task
    def collection
      Reimbursement::Report.pending.where.not(reviewer_id: nil).includes(:event)
    end

    def process(report)
      return if report.event.present? && report.eligible_reviewers.exists?(report.reviewer_id)

      report.reviewer = nil
      # Skip validations so unrelated legacy validation failures don't block the cleanup
      report.save!(validate: false)
    end

  end
end
