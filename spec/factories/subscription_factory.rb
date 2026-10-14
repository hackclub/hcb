# frozen_string_literal: true

FactoryBot.define do
  factory :subscription do
    stripe_card { association(:stripe_card, :with_stripe_id) }
    event { stripe_card.event }
    merchant_name { "Spotify" }
    merchant_network_id { "spotify-123" }
    amount_cents { 11_99 }
    cadence { "monthly" }
  end
end
