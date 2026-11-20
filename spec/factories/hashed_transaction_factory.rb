# frozen_string_literal: true

FactoryBot.define do
  factory :hashed_transaction do
    date { Faker::Date.backward(days: 14) }

    trait :plaid do
      association :raw_plaid_transaction
    end

    trait :emburse do
      association :raw_emburse_transaction
    end
  end
end
