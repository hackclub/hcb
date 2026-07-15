# frozen_string_literal: true

FactoryBot.define do
  factory :fee_revenue do
    amount_cents { Faker::Number.number(digits: 4) }
    start { 1.week.ago.to_date }
    add_attribute(:end) { Date.current }
  end
end
