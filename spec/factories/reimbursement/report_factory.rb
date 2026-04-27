# frozen_string_literal: true

FactoryBot.define do
  factory :reimbursement_report, class: "Reimbursement::Report" do
    association :user
    association :event
    name { "Test Report" }
  end
end
