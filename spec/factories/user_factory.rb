# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    email { Faker::Internet.email }
    full_name { Faker::Name.name }
    session_validity_preference { SessionsHelper::SESSION_DURATION_OPTIONS["3 days"] }

    trait :make_admin do
      access_level { :admin }
    end
  end
end
