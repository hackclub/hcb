# frozen_string_literal: true

FactoryBot.define do
  factory :ach_transfer do
    amount { 50 }
    routing_number { Faker::Bank.routing_number }
    account_number { Faker::Bank.account_number }
    bank_name { Faker::Bank.name }
    recipient_name { payment_recipient&.name || Faker::Name.name }
    recipient_email { Faker::Internet.email }
    association :event

    trait :without_payment_details do
      routing_number { nil }
      account_number { nil }
      bank_name { nil }
      recipient_name { nil }
    end
  end
end
