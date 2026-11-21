# frozen_string_literal: true

module FeeRevenueService
  # Every organization still owing fiscal sponsorship fees, paired with the
  # balance its ledger says is owed, largest first. The balance counts fees on
  # fronted (unsettled) revenue, so it is the fee exposure rather than the
  # amount the next weekly charge will collect.
  #
  # A pending bank fee is the running total of what hasn't been charged yet: the
  # ledger already nets its pending transaction out of the balance, so it goes
  # back in here. It only leaves the balance once the weekly job confirms it.
  class UnchargedFeeBalances
    def run
      Event.includes(:ledger, :plan, :pending_bank_fee).where(id: candidate_event_ids).filter_map do |event|
        # A regular bank fee is negative; see `HasBookTransfer`.
        balance = event.ledger.fronted_fee_balance_cents - (event.pending_bank_fee&.amount_cents || 0)
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
