# frozen_string_literal: true

FactoryBot.define do
  factory :invoice do
    association :sponsor
    association :creator, factory: :user
    item_description { Faker::Commerce.product_name }
    item_amount { Faker::Number.number(digits: 4) }
    payout_creation_balance_net { Faker::Number.number(digits: 4) }
    payout_creation_balance_stripe_fee { Faker::Number.number(digits: 4) }
    due_date { Faker::Date.forward(days: 14) }
  end
end
