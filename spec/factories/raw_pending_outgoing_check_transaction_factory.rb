# frozen_string_literal: true

FactoryBot.define do
  factory :raw_pending_outgoing_check_transaction do
    amount_cents { Faker::Number.number(digits: 4) }
  end
end
