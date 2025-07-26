# frozen_string_literal: true

FactoryBot.define do
  factory :card_grant do
    association :stripe_card, :with_stripe_id
    association :event
    association :user
    association :sent_by, factory: :user

    email { user.email }
    amount_cents { Faker::Number.number(digits: 4) }

    category_lock { [] }
    merchant_lock { [] }
    keyword_lock { nil }

    after(:create) do |card_grant|
      card_grant.stripe_card.update(subledger: card_grant.subledger)
    end
  end
end
