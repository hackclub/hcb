# frozen_string_literal: true

FactoryBot.define do
  factory :fee_reimbursement_group do
    # A different ISO week per group, walking back from last week
    sequence(:key) { |n| n.weeks.ago.strftime(FeeReimbursementGroup::KEY_FORMAT) }
  end
end
