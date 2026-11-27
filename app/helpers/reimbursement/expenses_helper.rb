# frozen_string_literal: true

module Reimbursement
  module ExpensesHelper
    # Every expense on a report renders its own "Move expense" form, so these
    # options are memoized to query once per request rather than once per expense.
    # rubocop:disable Rails/HelperInstanceVariable
    def move_expense_report_options(report)
      @move_expense_report_options ||= {}
      @move_expense_report_options[report.id] ||= begin
        reports = report.user.reimbursement_reports.draft.where.not(id: report.id)
        # Organizers moving someone else's expense can only authorize moves within their own event.
        reports = reports.where(event_id: report.event_id) unless admin_signed_in? || current_user == report.user
        reports.order(created_at: :desc).pluck(:name, :id)
      end
    end

    def move_expense_event_options
      @move_expense_event_options ||= current_user.events.not_hidden.filter_demo_mode(false).pluck(:name, :id)
    end
    # rubocop:enable Rails/HelperInstanceVariable

  end
end
