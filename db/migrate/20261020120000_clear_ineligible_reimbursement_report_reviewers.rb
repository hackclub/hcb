# frozen_string_literal: true

# Reports used to keep their assigned reviewer when moved to another
# organization, leaving reviewers who aren't managers of the report's
# organization. Only pending reports are touched so the reviewer on
# already-processed reports stays as a record.
class ClearIneligibleReimbursementReportReviewers < ActiveRecord::Migration[8.1]
  def up
    Reimbursement::Report.pending.where.not(reviewer_id: nil).includes(:event).find_each do |report|
      next if report.event.present? && report.eligible_reviewers.exists?(report.reviewer_id)

      report.reviewer = nil
      # Skip validations so unrelated legacy validation failures don't block the cleanup
      report.save!(validate: false)
    end
  end

  def down
    # Irreversible: the cleared reviewers didn't have access to the report's organization.
  end

end
