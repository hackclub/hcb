# frozen_string_literal: true

FactoryBot.define do
  factory :event do
    name { Faker::Name.unique.name }
    transient do
      plan_type { Event::Plan::FeeWaived }
      organizers { [] }
    end

    # Set the plan type up front. `Event#before_validation` builds a
    # plan with the fallback type (Event::Plan::Standard) when none is
    # set, so building the plan here saves an UPDATE + reload per
    # `create(:event)` — hit on ~250 event creations per suite run.
    after(:build) do |event, context|
      event.build_plan(type: context.plan_type.to_s) if context.plan_type.present? && event.plan.nil?
    end

    after(:create) do |event, context|
      context.organizers.each do |user|
        create(:organizer_position, event:, user:)
      end

      # Clear cached associations (e.g. `plan`) so specs like
      # spec/models/event_spec.rb "uses the standard plan as a fallback"
      # see post-callback state rather than the factory's in-memory copy.
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
