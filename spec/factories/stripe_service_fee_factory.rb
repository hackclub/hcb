# frozen_string_literal: true

FactoryBot.define do
  factory :stripe_service_fee do
    amount_cents { -Faker::Number.number(digits: 4) }
    stripe_description { "Stripe service fee" }
    sequence(:stripe_balance_transaction_id) { |n| "txn_#{n}" }
  end
end
