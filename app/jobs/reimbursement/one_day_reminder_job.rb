# frozen_string_literal: true

module Reimbursement
  class OneDayReminderJob < ApplicationJob
    queue_as :low
    def perform(report)
      return unless report.draft?
      return if report.deleted?

      if report.updated_at < 23.hours.ago
        ReimbursementMailer.with(report:).reminder.deliver_later
      else
        Reimbursement::OneDayReminderJob.set(wait: 1.day).perform_later(report)
      end
    end

  end
end

module ReimbursementJob
  OneDayReminder = Reimbursement::OneDayReminderJob
end
