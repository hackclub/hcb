# frozen_string_literal: true

FactoryBot.define do
  factory :raw_pending_incoming_disbursement_transaction do
    amount_cents { Faker::Number.number(digits: 4) }
    association :disbursement
  end
end
