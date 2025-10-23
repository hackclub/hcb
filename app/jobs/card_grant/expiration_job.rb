# frozen_string_literal: true

class CardGrant
  class ExpirationJob < ApplicationJob
    queue_as :low
    def perform
      CardGrant.active.expired_before(Time.now).find_each do |card_grant|
        card_grant.expire!
      end

      CardGrant.active.expires_on(3.days.from_now).find_each do |card_grant|
        CardGrantMailer.with(card_grant:, expiry_time: "3 days").card_grant_days_expire_notification.deliver_later
      end

      CardGrant.active.expires_on(1.month.from_now).find_each do |card_grant|
        CardGrantMailer.with(card_grant:, expiry_time: "1 month").card_grant_month_expire_notification.deliver_later
      end

    end

  end

end
