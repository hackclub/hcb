# frozen_string_literal: true

module PendingEventMappingEngine
  module Map
    module Single
      class FeeRevenue
        def initialize(canonical_pending_transaction:)
          @canonical_pending_transaction = canonical_pending_transaction
        end

        def run
          return @canonical_pending_transaction.canonical_pending_event_mapping if @canonical_pending_transaction.mapped?
          return unless @canonical_pending_transaction.raw_pending_fee_revenue_transaction.likely_event_id

          attrs = {
            event_id: @canonical_pending_transaction.raw_pending_fee_revenue_transaction.likely_event_id,
            canonical_pending_transaction_id: @canonical_pending_transaction.id
          }
          CanonicalPendingEventMapping.create!(attrs)
        end

      end
    end
  end
end
