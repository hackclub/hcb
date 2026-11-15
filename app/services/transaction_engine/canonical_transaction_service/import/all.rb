# frozen_string_literal: true

module TransactionEngine
  module CanonicalTransactionService
    module Import
      class All
        def run
          HashedTransaction.uncanonized.find_each(batch_size: 100) do |ht|
            # Create the CanonicalTransaction and settle its pending transaction
            # in one database transaction. Otherwise the ledger item's
            # amount_cents double counts the transaction (settled + still
            # unsettled pending) between the two commits.
            ActiveRecord::Base.transaction do
              ct = CanonicalTransaction.create!(
                date: ht.date,
                memo: ht.memo,
                amount_cents: ht.amount_cents,
                canonical_hashed_mappings: [CanonicalHashedMapping.new(hashed_transaction: ht)],
                transaction_source: ht.raw_plaid_transaction || ht.raw_emburse_transaction || ht.raw_stripe_transaction || ht.raw_csv_transaction || ht.raw_increase_transaction
              )

              ::PendingEventMappingEngine::Settle::Single::All.new(canonical_transaction: ct).run
            end
          end
        end

      end
    end
  end
end
