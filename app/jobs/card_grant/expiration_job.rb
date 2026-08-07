# frozen_string_literal: true

class CardGrant
  class ExpirationJob < ApplicationJob
    queue_as :low

    def perform
      # Because `expired_before` uses `<` instead of `<=`, the Card Grant will
      # be expired one day after the expiry date at midnight UTC (when the job is ran).
      CardGrant.active.expired_before(Date.today).find_each do |card_grant|
        card_grant.expire!
      end

      CardGrant.active.expires_on(3.days.from_now).find_each do |card_grant|
        CardGrantMailer.with(card_grant:, expiry_time: "3 days").card_grant_expiry_notification.deliver_later
      end

      CardGrant.active.expires_on(1.month.from_now).find_each do |card_grant|
        CardGrantMailer.with(card_grant:, expiry_time: "1 month").card_grant_expiry_notification.deliver_later
      end

    end

  end

end
