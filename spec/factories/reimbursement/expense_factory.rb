# frozen_string_literal: true

FactoryBot.define do
  factory :reimbursement_expense, class: "Reimbursement::Expense" do
    association :report, factory: :reimbursement_report
    value { 10.00 }
    description { "Test expense" }
  end
end
