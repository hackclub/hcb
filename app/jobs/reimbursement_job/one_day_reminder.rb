# frozen_string_literal: true

module ReimbursementJob
  class OneDayReminder < ApplicationJob
    queue_as :low
    def perform(report)
      return unless report.draft?

      if report.updated_at < 23.hours.ago
        ReimbursementMailer.with(report:).reminder.deliver_later
      else
        ReimbursementJob::OneDayReminder.set(wait: 1.day).perform_later(report)
      end
    end

  end
end
