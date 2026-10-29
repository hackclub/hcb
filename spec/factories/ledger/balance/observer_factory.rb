# frozen_string_literal: true

FactoryBot.define do
  factory :ledger_balance_observer, class: "Ledger::Balance::Observer" do
    association :ledger, factory: [:ledger, :primary_with_event]
    association :user
    amount_cents { 100_00 }
  end
end
