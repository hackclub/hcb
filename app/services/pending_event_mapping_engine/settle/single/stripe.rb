# frozen_string_literal: true

module PendingEventMappingEngine
  module Settle
    module Single
      class Stripe
        def initialize(canonical_transaction:)
          @canonical_transaction = canonical_transaction
        end

        def run
          # Refunds share the authorization id of the original charge they're
          # refunding, so they'd otherwise resolve to the same CPT as the
          # charge and settle it a second time (to the refund's CT instead of
          # the charge's CT). A CPT should only ever settle to the original
          # charge.
          return if @canonical_transaction.stripe_refund?

          raw_pending_stripe_transaction = RawPendingStripeTransaction.find_by(stripe_transaction_id: @canonical_transaction.raw_stripe_transaction.stripe_authorization_id)
          return if raw_pending_stripe_transaction.nil?

          cpt = raw_pending_stripe_transaction.canonical_pending_transaction

          CanonicalPendingTransactionService::Settle.new(
            canonical_transaction: @canonical_transaction,
            canonical_pending_transaction: cpt
          ).run!
        end

      end
    end
  end
end
