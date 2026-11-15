# frozen_string_literal: true

FactoryBot.define do
  factory :payee do
    association :event
    association :legal_entity
    display_name { Faker::Company.name }
    email { Faker::Internet.email }
  end
end
