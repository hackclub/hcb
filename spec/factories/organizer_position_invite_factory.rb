# frozen_string_literal: true

FactoryBot.define do
  factory :organizer_position_invite do
    association :event
    association :sender, factory: :user
    association :user

    trait :canceled do
      cancelled_at { Time.now }
    end

    trait :rejected do
      rejected_at { Time.now }
    end

    trait :accepted do
      after(:create) { |invite| invite.accept }
    end

    trait :sent_to_self do
      user { sender }
    end
  end
end
