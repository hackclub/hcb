# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }

    after(:build) do |user|
      if user.full_name.present?
        parsed = UserService::ParseName.new(full_name: user.full_name).run
        user.first_name = parsed.first_name
        user.last_name = parsed.last_name
      end
    end

    session_validity_preference { SessionsHelper::SESSION_DURATION_OPTIONS.fetch("3 days") }

    trait :make_admin do
      access_level { :admin }
    end
  end
end
