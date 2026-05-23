# frozen_string_literal: true

FactoryBot.define do
  factory :g_suite_account do
    association :g_suite
    association :creator, factory: :user
    address { "#{Faker::Internet.username(specifier: 5..10)}@#{g_suite.domain}" }
    backup_email { Faker::Internet.email }
    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }
    accepted_at { Time.current }
  end
end
