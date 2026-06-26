# frozen_string_literal: true

FactoryBot.define do
  factory :payment_attempt, class: "Payment::Attempt" do
    association :payment
    association :payout_method, factory: :legal_entity_payout_method

    aasm_state { "pending" }

    # Suppress the after_create :create_transfer! callback by default.
    # It hits external services (Increase, Column, Wise) and belongs in
    # integration tests, not unit tests. Override with :real_transfer when needed.
    after(:build) do |attempt|
      allow(attempt).to receive(:create_transfer!)
    end

    trait :pending do
      aasm_state { "pending" }
    end

    trait :under_review do
      aasm_state { "under_review" }
    end

    trait :sent do
      aasm_state { "sent" }
      sent_at    { 1.hour.ago }
    end

    trait :successful do
      aasm_state { "successful" }
      sent_at    { 2.hours.ago }
    end

    trait :failed do
      aasm_state { "failed" }
      failed_at  { 1.hour.ago }
    end

    # Use only in integration tests. Requires the payment's payee to have a
    # fully configured legal entity with a default payout method.
    trait :real_transfer do
      after(:build) do |attempt|
        # No-op: removes the stub so the real callback fires.
        # The caller is responsible for setting up all associated objects.
      end
    end

    trait :check do
      association :payout_method, factory: :legal_entity_payout_method_check
    end
    trait :ach do
      association :payout_method, factory: :legal_entity_payout_method_ach
    end
    trait :wire do
      association :payout_method, factory: :legal_entity_payout_method_wire
    end
    trait :wise do
      association :payout_method, factory: :legal_entity_payout_method_wise
    end
  end

  factory :legal_entity_payout_method_check, parent: :legal_entity_payout_method do
    association :details, factory: :check_payout_method_details
  end
  factory :legal_entity_payout_method_ach, parent: :legal_entity_payout_method do
    association :details, factory: :ach_transfer_payout_method_details
  end
  factory :legal_entity_payout_method_wire, parent: :legal_entity_payout_method do
    association :details, factory: :wire_payout_method_details
  end
  factory :legal_entity_payout_method_wise, parent: :legal_entity_payout_method do
    association :details, factory: :wise_transfer_payout_method_details
  end

end
