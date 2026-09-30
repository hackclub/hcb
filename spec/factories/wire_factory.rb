# frozen_string_literal: true

FactoryBot.define do
  factory :wire do
    association :event
    association :user
    amount_cents { 50_000 }
    currency { "USD" }
    memo { Faker::Lorem.sentence(word_count: 3) }
    payment_for { Faker::Lorem.sentence(word_count: 4).truncate(140) }
    recipient_name { Faker::Name.name }
    recipient_email { Faker::Internet.email }
    account_number { "DE89370400440532013000" }
    bic_code { "DEUTDEDB" }
    address_line1 { "123 Main St" }
    address_city { "Berlin" }
    address_postal_code { "10115" }
    address_state { "Berlin" }
    recipient_country { :DE }
    recipient_information { {} }

    trait :pending do
      aasm_state { "pending" }
    end

    trait :approved do
      aasm_state { "approved" }
    end

    trait :deposited do
      aasm_state { "deposited" }
    end
  end
end
