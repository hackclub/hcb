# frozen_string_literal: true

FactoryBot.define do
  factory :ledger_item, class: "Ledger::Item" do
    amount_cents { 1000 }
    short_code { "J3PDG" }
    marked_no_or_lost_receipt_at { nil }
  end
end
