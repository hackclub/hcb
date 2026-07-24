# frozen_string_literal: true

class Payment
  class AcceptanceReminderJob < ApplicationJob
    queue_as :low
    discard_on ActiveJob::DeserializationError

    def perform(payment, reminder_day)
      return unless payment.awaiting_recipient_onboarding?

      PaymentMailer.with(payment:).acceptance_reminder.deliver_later
    end

  end

end
