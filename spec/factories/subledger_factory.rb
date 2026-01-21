# frozen_string_literal: true

FactoryBot.define do
  factory :subledger do
    association :event
  end
end
