# frozen_string_literal: true

FactoryBot.define do
  factory :payment_recipient do
    routing_number { Faker::Bank.routing_number }
    account_number { Faker::Bank.account_number }
    bank_name { Faker::Bank.name }
    name { Faker::Name.name }
    email { Faker::Internet.email }
  end
end
