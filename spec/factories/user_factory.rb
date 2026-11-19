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
  end
end
