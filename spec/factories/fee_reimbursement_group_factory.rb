# frozen_string_literal: true

FactoryBot.define do
  factory :fee_reimbursement_group do
    # A different ISO week per group, walking back from last week
    sequence(:slug) { |n| n.weeks.ago.strftime(FeeReimbursementGroup::SLUG_FORMAT) }
  end
end
