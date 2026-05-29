# frozen_string_literal: true

FactoryBot.define do
  factory :increase_check do
    association :event, factory: [:event, :with_positive_balance]
    memo { "Test check" }
    amount { 10_000 }
    payment_for { "Event supplies" }
    recipient_name { Faker::Name.name }
    recipient_email { Faker::Internet.email }
    address_line1 { "1 Main St" }
    address_line2 { nil }
    address_city { Faker::Address.city }
    address_state { "CA" }
    address_zip { "94107" }

    trait :approved do
      aasm_state { "approved" }
    end
  end
end
