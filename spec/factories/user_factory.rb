# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    # A given `full_name:` is split by the model, so the defaults step aside.
    full_name { nil }
    legal_first_name { full_name.present? ? nil : Faker::Name.first_name }
    legal_last_name { full_name.present? ? nil : Faker::Name.last_name }
    session_validity_preference { SessionsHelper::SESSION_DURATION_OPTIONS.fetch("3 days") }
    verified { true }

    trait :make_admin do
      access_level { :admin }
    end

    trait :make_auditor do
      access_level { :auditor }
    end
  end
end
