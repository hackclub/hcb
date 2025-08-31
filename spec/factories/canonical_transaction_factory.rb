# frozen_string_literal: true

FactoryBot.define do
  factory :canonical_transaction do
    amount_cents { Faker::Number.number(digits: 4) }
    date { Faker::Date.backward(days: 14) }
    memo { Faker::Quote.matz }
    hashed_transactions { [association(:hashed_transaction, :plaid)] }

    transient do
      category_slug {}
    end

    after(:create) do |ct, context|
      if context.category_slug.present?
        TransactionCategoryService.new(model: ct).set!(slug: context.category_slug)
      end
    end
  end
end
