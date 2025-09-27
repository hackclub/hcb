# frozen_string_literal: true

class Disbursement
  class TransactionsHelper
    def initialize(disbursement)
      @disbursement = disbursement
    end

    def settled_source
      canonical_transactions_by_event.fetch(@disbursement.source_event, [])
    end

    def settled_destination
      canonical_transactions_by_event.fetch(@disbursement.destination_event, [])
    end

    def pending_source
      canonical_pending_transactions_by_event.fetch(@disbursement.source_event, [])
    end

    def pending_destination
      canonical_pending_transactions_by_event.fetch(@disbursement.destination_event, [])
    end

    private

    def canonical_transactions_by_event
      @canonical_transactions_by_event ||=
        @disbursement
        .canonical_transactions
        .strict_loading
        .preload(:event)
        .group_by(&:event)
    end

    def canonical_pending_transactions_by_event
      @canonical_pending_transactions_by_event ||=
        @disbursement
        .canonical_pending_transactions
        .strict_loading
        .preload(:event)
        .group_by(&:event)
    end

  end

end
