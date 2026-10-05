# frozen_string_literal: true

FactoryBot.define do
  factory :g_suite_alias do
    association :g_suite_account
    # Faker draws usernames from a pool of a few thousand values, so two aliases
    # on the same domain collided against the address uniqueness validation
    # often enough to fail CI at random. #unique never repeats a draw.
    address { "#{Faker::Internet.unique.username(specifier: 5..10)}@#{g_suite_account.g_suite.domain}" }
  end
end
