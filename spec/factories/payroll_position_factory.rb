# frozen_string_literal: true

FactoryBot.define do
  factory :payroll_position, class: "Payroll::Position" do
    association :payee
    title { Faker::Job.title }
    description { Faker::Lorem.sentence }
    rate_cents { 8_500 }
    currency { "USD" }
    start_date { Date.current }
    end_date { Date.current + 3.months }
  end
end
