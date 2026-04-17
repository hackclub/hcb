# frozen_string_literal: true

FactoryBot.define do
  factory :event do
    name { Faker::Name.unique.name }
    transient do
      plan_type { Event::Plan::FeeWaived }
      organizers { [] }
    end

    # Build the plan with the factory's `plan_type` up front. Without this,
    # `Event#before_validation` builds a plan of the fallback type (Standard)
    # and `after(:create)` had to UPDATE the plan to the desired type
    # afterwards — an extra INSERT + UPDATE round trip on every
    # `create(:event)`, paid on all ~250 event creations per suite run.
    after(:build) do |event, context|
      event.build_plan(type: context.plan_type.to_s) if context.plan_type.present? && event.plan.nil?
    end

    after(:create) do |event, context|
      context.organizers.each do |user|
        create(:organizer_position, event:, user:)
      end

      # Reload to clear cached associations (e.g. `plan`) that other tests
      # rely on being fresh after various callbacks run — see
      # spec/models/event_spec.rb "uses the standard plan as a fallback".
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
      after :create do |event|
        raw_csv_transaction = RawCsvTransactionService::Create.new(
          unique_bank_identifier: "FSMAIN",
          date: 3.days.ago.iso8601(3),
          memo: "🏦 Test Donation",
          amount: 1_000
        ).run

        TransactionEngine::HashedTransactionService::RawCsvTransaction::Import.new.run
        TransactionEngine::CanonicalTransactionService::Import::All.new.run

        CanonicalEventMapping.create!(
          canonical_transaction_id: CanonicalTransaction.find_by!(memo: raw_csv_transaction.memo).id,
          event_id: event.id,
        )
      end
    end
  end
end
