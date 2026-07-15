# frozen_string_literal: true

module Payroll
  class Position
    class OnboardingReminderJob < ApplicationJob
      queue_as :low
      discard_on ActiveJob::DeserializationError

      def perform(position, reminder_day)
        return unless position.onboarding_reminders_pending?

        Payroll::PositionMailer.with(position:, reminder_day:).onboarding_reminder.deliver_later
      end

    end

  end

end
