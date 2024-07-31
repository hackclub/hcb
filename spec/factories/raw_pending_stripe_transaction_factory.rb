# frozen_string_literal: true

FactoryBot.define do
  sequence :stripe_card_id do |n|
    "ic_#{n}"
  end

  factory :raw_pending_stripe_transaction do
    amount_cents { Faker::Number.number(digits: 4) }
    sequence(:stripe_transaction_id) { |n| "iauth_#{n}" }
    stripe_transaction {
      {
        "id": stripe_transaction_id,
        "card": {
          "id": generate(:stripe_card_id)
        },
        "authorization_method": "online",
        "merchant_data": { "name": "merchant 1" }
      }
    }
  end
end
