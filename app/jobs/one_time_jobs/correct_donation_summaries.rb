# frozen_string_literal: true

module OneTimeJobs
  class CorrectDonationSummaries
    def self.perform
      Event.includes(:donations)
           .where("donations.created_at > ? and donations.aasm_state != 'in_transit' and donations.aasm_state != 'deposited'", Date.new(2025, 4, 1))
           .references(:donations).find_each do |event|
        mailer = EventMailer.with(event: event, correction: true)
        mailer.monthly_donation_summary.deliver_later
      end
    end

  end
end
