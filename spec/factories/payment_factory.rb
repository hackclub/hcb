# frozen_string_literal: true

FactoryBot.define do
  factory :payment do
    association :payee
    association :creator, factory: :user

    amount_cents { 10_000 }
    currency     { "USD" }
    purpose      { "Reimbursement for conference travel" }
    aasm_state   { "pending_legal_entity" }

    trait :pending_legal_entity do
      aasm_state { "pending_legal_entity" }
    end

    trait :under_review do
      aasm_state      { "under_review" }
      under_review_at { 1.hour.ago }
    end

    trait :sent do
      aasm_state { "sent" }
      sent_at    { 30.minutes.ago }
    end

    trait :rejected do
      aasm_state  { "rejected" }
      rejected_at { 1.hour.ago }
    end
  end
end
