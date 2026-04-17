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
      # Event#balance is derived from the sum of amount_cents on mapped
      # canonical_transactions (see Event#settled_balance_cents). We insert
      # a single positive CanonicalTransaction + mapping directly instead of
      # running the full RawCsv -> Hashed -> Canonical import pipeline, which
      # costs ~1 second per use and is already covered by its own specs.
      #
      # 100_000 cents ($1,000) matches the original amount created by the
      # import pipeline (RawCsvTransaction#amount=1_000 is monetized to cents).
      after :create do |event|
        canonical_transaction = create(:canonical_transaction, amount_cents: 100_000, memo: "🏦 Test Donation")
        create(:canonical_event_mapping, canonical_transaction:, event:)
      end
    end
  end
end
