# frozen_string_literal: true

FactoryBot.define do
  factory :fee_reimbursement do
    amount { 1_23 }
    sequence(:transaction_memo) { |n| "HCB-FEE#{n}" }
  end
end
