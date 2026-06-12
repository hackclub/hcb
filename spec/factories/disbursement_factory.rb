# frozen_string_literal: true

FactoryBot.define do
  factory :disbursement do
    association :event
    association :source_event, factory: :event
    amount { Faker::Number.positive.to_i }
    name { Faker::Name.unique.name }

    trait :pending do
      aasm_state { "pending" }
      pending_at { Time.current }
      association :fulfilled_by, factory: :user
    end

    trait :scheduled do
      aasm_state { "scheduled" }
      scheduled_on { 1.week.from_now }
      association :fulfilled_by, factory: :user
    end

    trait :in_transit do
      aasm_state { "in_transit" }
      pending_at { 1.day.ago }
      in_transit_at { Time.current }
      association :fulfilled_by, factory: :user
    end

    trait :deposited do
      aasm_state { "deposited" }
      pending_at { 2.days.ago }
      in_transit_at { 1.day.ago }
      deposited_at { Time.current }
      association :fulfilled_by, factory: :user
    end

    trait :rejected do
      aasm_state { "rejected" }
      rejected_at { Time.current }
      association :fulfilled_by, factory: :user
    end

    trait :errored do
      aasm_state { "errored" }
      errored_at { Time.current }
    end

    trait :with_raw_pending_transactions do
      after(:create) do |disbursement|
        create(:raw_pending_outgoing_disbursement_transaction, disbursement:, amount_cents: -disbursement.amount)
        create(:raw_pending_incoming_disbursement_transaction, disbursement:, amount_cents: disbursement.amount)
      end
    end

    trait :with_canonical_transactions do
      after(:create) do |disbursement|
        create(:canonical_transaction, hcb_code: disbursement.hcb_code, amount_cents: -disbursement.amount)
        create(:canonical_transaction, hcb_code: disbursement.hcb_code, amount_cents: disbursement.amount)
      end
    end
  end
end
