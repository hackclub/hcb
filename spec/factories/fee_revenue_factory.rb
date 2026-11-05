# frozen_string_literal: true

FactoryBot.define do
  factory :fee_revenue do
    amount_cents { Faker::Number.number(digits: 4) }
    start { Date.current.beginning_of_month }
    add_attribute(:end) { Date.current.end_of_month }
  end
end
