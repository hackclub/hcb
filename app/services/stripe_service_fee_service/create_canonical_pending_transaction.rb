# frozen_string_literal: true

module StripeServiceFeeService
  class CreateCanonicalPendingTransaction
    def initialize(stripe_service_fee_id:)
      @stripe_service_fee_id = stripe_service_fee_id
    end

    # Idempotent: safe to re-run (e.g. from the nightly StripeServiceFeeJob) —
    # it no-ops once the stripe service fee already has its raw pending transaction.
    def run
      existing = stripe_service_fee.raw_pending_stripe_service_fee_transaction
      return existing.canonical_pending_transaction if existing.present?

      ActiveRecord::Base.transaction do
        rpssft = stripe_service_fee.create_raw_pending_stripe_service_fee_transaction!(
          date_posted: stripe_service_fee.created_at.to_date,
          amount_cents: stripe_service_fee.amount_cents
        )

        canonical_pending_transaction = CanonicalPendingTransaction.create!(
          date: rpssft.date,
          amount_cents: rpssft.amount_cents,
          memo: rpssft.memo,
          raw_pending_stripe_service_fee_transaction: rpssft
        )

        TransactionCategoryService
          .new(model: canonical_pending_transaction)
          .set!(
            slug: "stripe-service-fees",
            assignment_strategy: :automatic
          )

        CanonicalPendingEventMapping.create!(
          event: stripe_service_fee.event,
          canonical_pending_transaction:
        )

        canonical_pending_transaction
      end
    end

    private

    def stripe_service_fee
      @stripe_service_fee ||= StripeServiceFee.find(@stripe_service_fee_id)
    end

  end
end
