# frozen_string_literal: true

module Payroll
  class Position
    class OnboardingReminderJob < ApplicationJob
      queue_as :low
      discard_on ActiveJob::DeserializationError

      def perform(position)
        return if position.payee.managed?

        return unless position.onboarding? && position.contractor_onboarding_incomplete?

        Payroll::PositionMailer.with(position:).onboarding_reminder.deliver_later
      end

    end

  end

end
