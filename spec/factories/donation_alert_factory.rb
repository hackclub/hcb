# frozen_string_literal: true

FactoryBot.define do
  factory :donation_alert, class: "Donation::Alert" do
    association :event
    alert_name { Faker::Lorem.word }
    amount_cents { Faker::Number.number(digits: 4) }
    alert_message { Faker::Lorem.sentence }
    active { true }

    trait :inactive do
      active { false }
    end

    trait :with_subscribers do
      after(:create) do |alert|
        create_list(:user, 2).each { |user| alert.subscribe(user) }
      end
    end
  end
end
