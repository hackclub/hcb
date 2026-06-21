# frozen_string_literal: true

module DonationService
  class Alert
    def initialize(donation)
      @donation = donation
      @event = donation.event
    end

    def run
      return unless @event.donation_alerts.active.any?

      applicable_alerts.each do |alert|
        send_alert_emails(alert)
      end
    end

    private

    def applicable_alerts
      @applicable_alerts ||= @event.donation_alerts.active
                                   .where("amount_cents <= ?", @donation.amount)
    end

    def send_alert_emails(alert)
      alert.users.each do |user|
        DonationMailer.with(
          user: user,
          donation: @donation,
          alert: alert
        ).alert_notification.deliver_later
      end
    end

  end
end
