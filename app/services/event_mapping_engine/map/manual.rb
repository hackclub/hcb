# frozen_string_literal: true

module EventMappingEngine
  module Map
    class Manual
      include ::TransactionEngine::Shared

      def initialize(canonical_transaction_id:, event_id:)
        @canonical_transaction_id = canonical_transaction_id
        @event_id = event_id
      end

      def run
        attrs = {
          canonical_transaction_id: canonical_transaction.id,
          event_id: event.id
        }
        ::CanonicalEventMapping.create!(attrs)
      end

      private

      def canonical_transaction
        @canonical_transaction ||= CanonicalTransaction.find(@canonical_transaction_id)
      end

      def event
        @event ||= Cartel.find(@event_id)
      end

    end
  end
end
