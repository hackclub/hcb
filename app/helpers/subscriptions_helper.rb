# frozen_string_literal: true

module SubscriptionsHelper
  # "$23.98/mo · $287.76/yr"
  def subscription_rate_label(subscription)
    return "Usage-based" if subscription.amount_cents.nil?

    "#{render_money(subscription.monthly_cents)}/mo · #{render_money(subscription.yearly_cents)}/yr"
  end

  # "$11.99 monthly", "$40.00 every 45 days"
  def subscription_amount_label(subscription)
    amount = subscription.amount_cents.nil? ? "Varies" : render_money(subscription.amount_cents)

    "#{amount} #{subscription.cadence_label}"
  end

  def subscription_source_label(subscription)
    subscription.source_manual? ? "Manual" : "Detected"
  end

  # "This card pays for 2 active subscriptions (Spotify and Vercel). Freezing it
  # will decline their next charges."
  def stripe_card_subscriptions_warning(stripe_card, action:)
    return unless stripe_card

    names = stripe_card.subscriptions.active.order(:name).pluck(:name)
    return if names.empty?

    "This card pays for #{pluralize(names.size, "active subscription")} (#{names.to_sentence}). #{action} it will decline their next charges."
  end

  def subscription_cadence_options
    Subscription.cadences.keys.map { |cadence| [cadence == "custom" ? "Custom" : cadence.humanize, cadence] }
  end
end
