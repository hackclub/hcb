# frozen_string_literal: true

FactoryBot.define do
  factory :payee do
    association :event
    association :legal_entity
    preferred_name { Faker::Company.name }
  end
end
