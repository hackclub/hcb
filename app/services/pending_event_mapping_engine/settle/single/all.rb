# frozen_string_literal: true

module PendingEventMappingEngine
  module Settle
    module Single
      # Settles a freshly created CanonicalTransaction against its pending
      # transaction. Run this inside the same database transaction that creates
      # the CanonicalTransaction so the CanonicalPendingSettledMapping commits
      # with it: Ledger::Item#calculate_amount_cents sums settled transactions
      # plus *unsettled* pending transactions, so a committed CanonicalTransaction
      # whose pending transaction is still unsettled is counted twice until the
      # mapping lands.
      #
      # PendingEventMappingEngine::Nightly still sweeps unsettled pending
      # transactions for anything this can't match at creation time (e.g. the
      # pending transaction doesn't exist yet, or the HCB code is only resolved
      # later by TransactionGroupingEngine).
      class All
        def initialize(canonical_transaction:)
          @canonical_transaction = canonical_transaction
        end

        def run
          return if @canonical_transaction.canonical_pending_settled_mapping.present?

          if @canonical_transaction.likely_stripe_card_transaction?
            ::PendingEventMappingEngine::Settle::Single::Stripe.new(canonical_transaction: @canonical_transaction).run
          else
            ::PendingEventMappingEngine::Settle::Single::HcbCode.new(canonical_transaction: @canonical_transaction).run
          end
        end

      end
    end
  end
end
