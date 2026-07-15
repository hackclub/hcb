# frozen_string_literal: true

module PendingEventMappingEngine
  module Map
    class FeeRevenue
      def run
        unmapped.find_each(batch_size: 100) do |cpt|
          ::PendingEventMappingEngine::Map::Single::FeeRevenue.new(canonical_pending_transaction: cpt).run
        end
      end

      private

      def unmapped
        CanonicalPendingTransaction.unmapped.fee_revenue
      end

    end
  end
end
