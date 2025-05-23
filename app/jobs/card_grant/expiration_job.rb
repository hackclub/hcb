# frozen_string_literal: true

class CardGrant
  class ExpirationJob < ApplicationJob
    queue_as :low

    NOTIFICATION_WINDOWS = {
      "24 hours" => 24.hours,
      "3 days"   => 3.days,
      "1 month"  => 1.month
    }.freeze

    def perform
      CardGrant.active.expired_before(Time.now).find_each do |card_grant|
        card_grant.expire!
      end

      NOTIFICATION_WINDOWS.each do |notification_text, window|
        CardGrant.active
                .expires_between(Time.now, window.from_now)
                .where("last_expiry_notification_sent_at IS NULL OR last_expiry_notification_sent_at < ?", (window/2).ago)
                .find_each do |card_grant|
          CardGrantMailer.with(card_grant:, expiry_time: notification_text).card_grant_expiry_notification.deliver_later
          card_grant.update!(last_expiry_notification_sent_at: Time.current)
        end
      end
    end
  end
end
