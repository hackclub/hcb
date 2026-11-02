# frozen_string_literal: true

module FeeRevenueService
  class CreateCanonicalPendingTransaction
    def initialize(fee_revenue_id:)
      @fee_revenue_id = fee_revenue_id
    end

    # Idempotent: safe to re-run (e.g. from the nightly) — it no-ops once the
    # fee revenue already has its raw pending transaction.
    def run
      existing = fee_revenue.raw_pending_fee_revenue_transaction
      return existing.canonical_pending_transaction if existing.present?

      ActiveRecord::Base.transaction do
        rpfrt = fee_revenue.create_raw_pending_fee_revenue_transaction!(
          date_posted: fee_revenue.end,
          amount_cents: fee_revenue.amount_cents
        )

        canonical_pending_transaction = CanonicalPendingTransaction.create!(
          date: rpfrt.date,
          amount_cents: rpfrt.amount_cents,
          memo: rpfrt.memo,
          raw_pending_fee_revenue_transaction: rpfrt,
          fronted: true
        )

        TransactionCategoryService
          .new(model: canonical_pending_transaction)
          .set!(
            slug: "hcb-revenue",
            assignment_strategy: :automatic
          )

        CanonicalPendingEventMapping.create!(
          event: fee_revenue.event,
          canonical_pending_transaction:
        )

        canonical_pending_transaction
      end
    end

    private

    def fee_revenue
      @fee_revenue ||= FeeRevenue.find(@fee_revenue_id)
    end

  end
end
