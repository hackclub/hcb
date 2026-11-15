# frozen_string_literal: true

FactoryBot.define do
  factory :bank_fee do
    association(:event)
    amount_cents { rand(1..9999) }
  end
end
