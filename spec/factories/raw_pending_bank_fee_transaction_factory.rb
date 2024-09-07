# frozen_string_literal: true

FactoryBot.define do
  factory :raw_pending_bank_fee_transaction do
    amount_cents { Faker::Number.number(digits: 4) }
  end
end
