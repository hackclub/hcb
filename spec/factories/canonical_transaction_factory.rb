# frozen_string_literal: true

FactoryBot.define do
  factory :canonical_transaction do
    amount_cents { Faker::Number.number(digits: 4) }
    date { Faker::Date.backward(days: 14) }
    memo { Faker::Quote.matz }
    hashed_transactions { [association(:hashed_transaction, :plaid)] }

    transient do
      category_name {}
    end

    after(:create) do |ct, context|
      if context.category_name.present?
        TransactionCategoryService.new(model: ct).set!(name: context.category_name)
      end
    end
  end
end
