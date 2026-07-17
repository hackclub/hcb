# frozen_string_literal: true

FactoryBot.define do
  factory :fee_reimbursement do
    sequence(:transaction_memo) { |n| "HCB-FEEREIMB#{n}" }
    amount { 12_34 }
  end
end
