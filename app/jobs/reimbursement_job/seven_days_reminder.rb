# frozen_string_literal: true

module ReimbursementJob
  class SevenDaysReminder < ApplicationJob
    queue_as :low
    def perform(report)
      return unless report.draft?
      return if report.deleted?

      if report.updated_at < 6.days.ago
        ReimbursementMailer.with(report:).reminder.deliver_later
      else
        ReimbursementJob::SevenDaysReminder.set(wait: 1.day).perform_later(report)
      end
    end

  end
end
