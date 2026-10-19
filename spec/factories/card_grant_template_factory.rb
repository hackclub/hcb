# frozen_string_literal: true

FactoryBot.define do
  factory :card_grant_template do
    association :event
    association :created_by, factory: :user

    sequence(:name) { |n| "Template #{n}" }
    amount_cents { 25_00 }
  end
end
