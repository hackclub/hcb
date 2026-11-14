# frozen_string_literal: true

FactoryBot.define do
  factory :recurring_donation do
    association :event
    name { Faker::Name.name }
    email { Faker::Internet.email }
    amount { 10_00 }
    # Setting the subscription skips the callback that creates one on Stripe.
    stripe_subscription_id { "sub_#{SecureRandom.alphanumeric(14)}" }
    stripe_customer_id { "cus_#{SecureRandom.alphanumeric(14)}" }
    stripe_status { "active" }
    stripe_current_period_end { 1.month.from_now }

    trait :canceled do
      stripe_status { "canceled" }
      canceled_at { 1.day.ago }
    end
  end
end
