# frozen_string_literal: true

FactoryBot.define do
  sequence :stripe_card_id do |n|
    "ic_#{n}"
  end

  factory :raw_pending_stripe_transaction do
    amount_cents { Faker::Number.number(digits: 4) }
    sequence(:stripe_transaction_id) { |n| "iauth_#{n}" }

    transient do
      # With a card, the charge resolves to it and to its cardholder, the way a
      # real authorization does. Without one it points at a card that doesn't
      # exist.
      stripe_card { nil }
      stripe_merchant_category { "bakeries" }
      stripe_merchant_category_code { nil }
    end

    stripe_transaction {
      {
        "id": stripe_transaction_id,
        "card": {
          "id": stripe_card&.stripe_id || generate(:stripe_card_id)
        },
        "cardholder": stripe_card&.stripe_cardholder&.stripe_id,
        "authorization_method": "online",
        "merchant_currency": "usd",
        "verification_data": {
          "address_line1_check": "not_provided",
          "address_postal_code_check": "not_provided",
          "cvc_check": "not_provided",
          "expiry_check": "match"
        },
        "merchant_data": {
          "name": "merchant 1",
          "category": stripe_merchant_category,
          "category_code": stripe_merchant_category_code
        }.compact
      }.compact
    }
  end
end
