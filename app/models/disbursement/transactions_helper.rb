# frozen_string_literal: true

class Disbursement
  class TransactionsHelper
    def initialize(disbursement)
      @disbursement = disbursement
    end

    def settled_source
      grouped_canonical_transactions.fetch(source_key, [])
    end

    def settled_destination
      grouped_canonical_transactions.fetch(destination_key, [])
    end

    def pending_source
      grouped_canonical_pending_transactions.fetch(source_key, [])
    end

    def pending_destination
      grouped_canonical_pending_transactions.fetch(destination_key, [])
    end

    private

    def source_key
      [@disbursement.source_event_id, @disbursement.source_subledger_id]
    end

    def destination_key
      [@disbursement.event_id, @disbursement.destination_subledger_id]
    end

    def grouped_canonical_transactions
      @grouped_canonical_transactions ||=
        @disbursement
        .canonical_transactions
        .preload(:canonical_event_mapping)
        .group_by do |ct|
          [
            ct.canonical_event_mapping.event_id,
            ct.canonical_event_mapping.subledger_id
          ]
        end
    end

    def grouped_canonical_pending_transactions
      @grouped_canonical_pending_transactions ||=
        @disbursement
        .canonical_pending_transactions
        .preload(:canonical_pending_event_mapping)
        .group_by do |cpt|
          [
            cpt.canonical_pending_event_mapping.event_id,
            cpt.canonical_pending_event_mapping.subledger_id
          ]
        end
    end

  end

end
