# frozen_string_literal: true

FactoryBot.define do
  factory :card_charge do
    raw_pending_stripe_transaction
  end
end
