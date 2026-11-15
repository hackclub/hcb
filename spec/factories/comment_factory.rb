# frozen_string_literal: true

FactoryBot.define do
  factory :comment do
    association :user
    content { Faker::Quote.matz }

    # A comment left on an HcbCode before comments moved to ledger items
    # (#14105). New comments on a code are moved onto its ledger item by a
    # before_validation hook, which saving without validation skips.
    trait :legacy_on_hcb_code do
      to_create { |comment| comment.save!(validate: false) }
    end
  end
end
