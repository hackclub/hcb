# frozen_string_literal: true

FactoryBot.define do
  factory :raw_stripe_transaction do
    amount_cents { Faker::Number.number(digits: 4) }
    unique_bank_identifier { "STRIPEISSUING1" }
    stripe_transaction { { "merchant_data": { "name": Faker::Name.name, "category": "bakeries" } } }
  end
end
