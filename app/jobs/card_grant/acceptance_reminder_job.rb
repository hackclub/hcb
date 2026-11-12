# frozen_string_literal: true

class CardGrant
  class AcceptanceReminderJob < ApplicationJob
    queue_as :low

    # Roughly 1 week, 2 weeks, 1 month, 3 months, and 6 months.
    # Fixed day counts avoid repeating reminders at the end of short months.
    REMINDER_DAYS = [7, 14, 30, 90, 180].freeze

    def perform
      REMINDER_DAYS.each do |days|
        CardGrant.not_activated.not_suspected_fraud
                 .where(expiration_at: Date.current..)
                 .where(created_at: days.days.ago.all_day)
                 .find_each do |card_grant|
          CardGrantMailer.with(card_grant:).acceptance_reminder.deliver_later
        end
      end
    end

  end

end
