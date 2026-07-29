# frozen_string_literal: true

module Payroll
  class Position
    class OnboardingReminderJob < ApplicationJob
      queue_as :low
      discard_on ActiveJob::DeserializationError

      def perform(position)
        # Managed contractors have their onboarding handled by the org, so they
        # don't get these nudges.
        return if position.payee.managed?

        # Stop once they've finished (or the position is no longer onboarding).
        return unless position.onboarding? && position.contractor_onboarding_incomplete?

        Payroll::PositionMailer.with(position:).onboarding_reminder.deliver_later
      end

    end

  end

end
