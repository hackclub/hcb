# frozen_string_literal: true

module FeeRevenueService
  # Every organization still owing fiscal sponsorship fees, paired with the
  # balance its ledger says is owed, largest first. The balance counts fees on
  # fronted (unsettled) revenue, so it is the fee exposure rather than the
  # amount the next weekly charge will collect.
  class UnchargedFeeBalances
    def run
      Event.includes(:ledger, :plan).where(id: candidate_event_ids).filter_map do |event|
        balance = event.ledger.fronted_fee_balance_cents
        { event:, balance: } unless balance.zero?
      end.sort_by { |item| -item[:balance] }
    end

    private

    # A nonzero balance needs fees accrued on settled revenue or on fronted
    # revenue that hasn't settled yet, so only those organizations get the
    # per-ledger computation.
    def candidate_event_ids
      settled = Event.event_ids_with_pending_fees.to_a.map { |row| row["event_id"] }

      fronted_transaction_ids = CanonicalPendingTransaction.incoming.fronted.not_waived.not_declined.unsettled.pluck(:id)
      fronted = CanonicalPendingEventMapping.where(canonical_pending_transaction_id: fronted_transaction_ids).distinct.pluck(:event_id)

      settled | fronted
    end

  end
end
