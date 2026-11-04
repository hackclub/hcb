# frozen_string_literal: true

class StripeCard
  class ExpirationJob < ApplicationJob
    queue_as :low
    def perform
      StripeCard.where.not(stripe_status: "canceled").find_each do |card|
        if card.expired?
          card.cancel!
          # Only cards that expired last month, so long-expired cards are canceled quietly
          notify(card, :expired) if card.expires_on == Date.current.prev_month.end_of_month
        elsif card.expires_on == (Date.current + 2.months).end_of_month
          # About 3 months before it expires
          notify(card, :expiring_soon)
        end
      rescue => e
        Rails.error.report(e, context: { stripe_card_id: card.id })
      end
    end

    private

    def notify(card, email)
      return unless StripeCardPolicy.new(card.user, card).replace_expired?

      StripeCardMailer.with(card_id: card.id).public_send(email).deliver_later
    end

  end

end
