# frozen_string_literal: true

module PendingEventMappingEngine
  module AnomalyDetection
    class BadSettledMapping
      def initialize(canonical_pending_transaction:)
        @canonical_pending_transaction = canonical_pending_transaction
      end

      def run
        return false unless @canonical_pending_transaction.settled?

        return true if canonical_transactions.count > 1

        return true if canonical_transaction_is_prior_to_the_pending_transaction?

        false
      end

      private

      def canonical_transactions
        @canonical_pending_transaction.canonical_transactions
      end

      def canonical_transaction
        canonical_transactions.first
      end

      def canonical_transaction_is_prior_to_the_pending_transaction?
        @canonical_pending_transaction.date >= canonical_transaction.date + 1.1.days # allow for slight time shift here given timezones
      end

    end
  end
end
