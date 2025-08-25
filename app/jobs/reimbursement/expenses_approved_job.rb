# frozen_string_literal: true

module Reimbursement
  class ExpensesApprovedJob < ApplicationJob
    queue_as :default

    def perform
      approvals = PaperTrail::Version.where_object_changes_to(aasm_state: "approved")
                                     .select { |version| version.item_type == "Reimbursement::Expense" && version.created_at > 20.minutes.ago }

      approved_expenses_by_report = {}

      approvals.each do |approval|
        expense = Reimbursement::Expense.find(approval.item_id)
        report = expense.report

        next unless expense.approved? && report.submitted?

        unless approved_expenses_by_report.key?(report)
          approved_expenses_by_report[report] = []
        end

        approved_expenses_by_report[report].append(expense)
      end

      approved_expenses_by_report.each do |report, expenses|
        ReimbursementMailer.with(report:, expenses:).expenses_approved.deliver_later
      end
    end

  end
end
