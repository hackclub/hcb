# frozen_string_literal: true

FactoryBot.define do
  factory :g_suite_alias do
    association :g_suite_account
    address { "#{Faker::Internet.username(specifier: 5..10)}@#{g_suite_account.g_suite.domain}" }
  end
end
