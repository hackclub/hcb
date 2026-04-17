# frozen_string_literal: true

FactoryBot.define do
  factory :event do
    name { Faker::Name.unique.name }
    transient do
      plan_type { Event::Plan::FeeWaived }
      organizers { [] }
    end

    after(:create) do |event, context|
      event.plan.update!(type: context.plan_type) if context.plan_type.present?

      context.organizers.each do |user|
        create(:organizer_position, event:, user:)
      end

      event.reload
    end

    factory :event_with_organizer_positions do
      after(:create) do |e|
        create_list(:organizer_position, 3, event: e)
      end
    end

    trait :demo_mode do
      demo_mode { true }
    end

    trait :card_grant_event do
      association :card_grant_setting
    end

    trait :with_positive_balance do
      # Event#balance sums amount_cents on mapped canonical_transactions
      # (see Event#settled_balance_cents), so a single positive mapping
      # is enough to give the event a balance for tests that need one.
      after :create do |event|
        canonical_transaction = create(:canonical_transaction, amount_cents: 100_000, memo: "🏦 Test Donation")
        create(:canonical_event_mapping, canonical_transaction:, event:)
      end
    end
  end
end
