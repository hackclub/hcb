# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    # Passing `full_name:` is still supported: the model splits it into
    # `first_name` / `last_name` on validation, so the defaults step aside.
    full_name { nil }
    first_name { full_name.present? ? nil : Faker::Name.first_name }
    last_name { full_name.present? ? nil : Faker::Name.last_name }
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
