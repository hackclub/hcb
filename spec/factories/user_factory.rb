# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    email { Faker::Internet.email }
    # `Faker::Name.name` can add titles and suffixes ("Van Feest Jr.") that
    # Namae can't parse, which leaves the legal first name blank.
    full_name { "#{Faker::Name.first_name} #{Faker::Name.last_name}" }
    session_validity_preference { SessionsHelper::SESSION_DURATION_OPTIONS.fetch("3 days") }
    verified { true }

    trait :make_admin do
      access_level { :admin }
    end

    trait :make_auditor do
      access_level { :auditor }
    end

    # Two-factor authentication needs a verified second factor, and saving a
    # new phone number un-verifies it, so the switches go on after creation.
    trait :with_two_factor_authentication do
      phone_number { "+18556254225" }

      after(:create) do |user|
        user.update!(phone_number_verified: true, use_two_factor_authentication: true)
      end
    end
  end
end
