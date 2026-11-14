# frozen_string_literal: true

class StripeCard
  class ExpirationJob < ApplicationJob
    queue_as :low
    def perform
      today = Date.current
      cards = StripeCard.where.not(stripe_status: %w[canceled deleted]).where.not(stripe_id: nil)

      cards.where("(stripe_exp_year, stripe_exp_month) < (?, ?)", today.year, today.month).find_each do |card|
        card.cancel!
        # cards that expired last month (we dont notify for older ones)
        notify(card, :expired) if card.expires_on == today.prev_month.end_of_month
      rescue => e
        report(e, card)
      end

      # ~3 months before expiry
      reminder_month = today + 2.months
      cards.where(stripe_exp_year: reminder_month.year, stripe_exp_month: reminder_month.month).find_each do |card|
        notify(card, :expiring_soon)
      rescue => e
        report(e, card)
      end
    end

    private

    def report(error, card)
      Rails.error.report(error, context: { stripe_card_id: card.id })
    end

    def notify(card, email)
      return unless StripeCardPolicy.new(card.user, card).replace_expired?

      StripeCardMailer.with(card_id: card.id).public_send(email).deliver_later
    end

  end

end
