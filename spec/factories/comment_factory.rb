# frozen_string_literal: true

FactoryBot.define do
  factory :comment do
    association :user
    content { Faker::Quote.matz }
  end
end
