# frozen_string_literal: true

FactoryBot.define do
  factory :ledger do
    primary { false }

    trait :primary_with_event do
      primary { true }
      association :event
    end

    trait :primary_with_card_grant do
      primary { true }
      association :card_grant
    end

    trait :with_event do
      association :event
    end

    trait :with_card_grant do
      association :card_grant
    end
  end
end
