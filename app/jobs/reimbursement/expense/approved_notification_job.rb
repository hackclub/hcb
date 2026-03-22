# frozen_string_literal: true

module Reimbursement
  class Expense
    class ApprovedNotificationJob < ApplicationJob
      queue_as :default

      def perform
        approvals = PaperTrail::Version.where_object_changes_to(aasm_state: "approved")
                                       .select { |version| version.item_type == "Reimbursement::Expense" && version.created_at > 20.minutes.ago }

        approved_expenses_without_report = approvals.filter_map do |approval|
          expense = Reimbursement::Expense.find(approval.item_id)
          report = expense.report

          expense if expense.approved? && report.submitted?
        end.uniq

        approved_expenses_by_report = approved_expenses_without_report.group_by { |expense| expense.report }

        approved_expenses_by_report.each do |report, expenses|
          ReimbursementMailer.with(report:, expenses:).expenses_approved.deliver_later
        end
      end


    end

  end
end
