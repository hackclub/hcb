# frozen_string_literal: true

FactoryBot.define do
  factory :canonical_pending_transaction do
    amount_cents { Faker::Number.number(digits: 4) }
    date { Faker::Date.backward(days: 14) }
    memo { Faker::Quote.matz }
    fronted { false }

    transient do
      category_slug {}
    end

    after(:create) do |cpt, context|
      if context.category_slug.present?
        TransactionCategoryService.new(model: cpt).set!(slug: context.category_slug)
      end

      # When a spec passes `event:` (via the has_one :through association), map
      # the ledger item onto that event's ledger. See FactoryLedgerMapping.
      FactoryLedgerMapping.map_to_primary_ledger(cpt)
    end
  end
end
