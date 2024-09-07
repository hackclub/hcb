# frozen_string_literal: true

FactoryBot.define do
  factory :stripe_cardholder do
    association :user

    stripe_id { "" }
    stripe_billing_address_line1 { "8605 Santa Monica Blvd #86294" }
    stripe_billing_address_city { "West Hollywood" }
    stripe_billing_address_state { "CA" }
    stripe_billing_address_postal_code { "90069" }
    stripe_billing_address_country { "US" }
  end
end
