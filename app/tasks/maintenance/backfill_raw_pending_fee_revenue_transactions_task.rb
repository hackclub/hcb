# frozen_string_literal: true

module Maintenance
  # Backfills RawPendingFeeRevenueTransactions (and their canonical pending
  # transactions, event mappings, and settled mappings) for FeeRevenues created
  # before the model existed. The nightly engines only import pending or
  # in-transit FeeRevenues, so historical ones must be backfilled here.
  class BackfillRawPendingFeeRevenueTransactionsTask < MaintenanceTasks::Task
    class AnomalyError < StandardError; end

    def collection
      FeeRevenue.all
    end

    def process(fee_revenue)
      if fee_revenue.amount_cents.nil? || fee_revenue.start.nil? || fee_revenue.end.nil?
        Rails.error.report AnomalyError.new("FeeRevenue #{fee_revenue.id} is missing amount_cents, start, or end; skipping")
        return
      end

      raw_pending_fee_revenue_transaction = RawPendingFeeRevenueTransaction.find_or_initialize_by(fee_revenue_transaction_id: fee_revenue.id.to_s).tap do |t|
        t.amount_cents = fee_revenue.amount_cents
        t.date_posted = fee_revenue.created_at
      end
      raw_pending_fee_revenue_transaction.save!

      cpt = ::PendingTransactionEngine::CanonicalPendingTransactionService::ImportSingle::FeeRevenue.new(raw_pending_fee_revenue_transaction:).run

      ::PendingEventMappingEngine::Map::Single::FeeRevenue.new(canonical_pending_transaction: cpt).run

      return if cpt.settled?

      ct = cpt.local_hcb_code&.canonical_transactions&.first
      if ct.nil?
        # A settled FeeRevenue should always have a canonical transaction at
        # its hcb code — that's what marked it settled in the first place.
        Rails.error.report AnomalyError.new("FeeRevenue #{fee_revenue.id} is settled but has no canonical transaction at #{fee_revenue.hcb_code}") if fee_revenue.settled?
        return
      end

      ::CanonicalPendingTransactionService::Settle.new(
        canonical_transaction: ct,
        canonical_pending_transaction: cpt
      ).run!
    end

  end
end
