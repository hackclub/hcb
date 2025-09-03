# frozen_string_literal: true

FactoryBot.define do
  factory :g_suite do
    association :event, factory: :event_with_organizer_positions
    domain { Faker::Internet.domain_name }
  end
end
