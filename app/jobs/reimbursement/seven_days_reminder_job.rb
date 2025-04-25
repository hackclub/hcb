# frozen_string_literal: true

module Reimbursement
  class SevenDaysReminderJob < ApplicationJob
    queue_as :low
    def perform(report)
      return unless report.draft?
      return if report.deleted?

      if report.updated_at < 6.days.ago
        ReimbursementMailer.with(report:).reminder.deliver_later
      else
        Reimbursement::SevenDaysReminderJob.set(wait: 1.day).perform_later(report)
      end
    end

  end
end

module ReimbursementJob
  SevenDaysReminder = Reimbursement::SevenDaysReminderJob
end
