# frozen_string_literal: true

module PendingEventMappingEngine
  module Settle
    class FeeRevenueHcbCode
      def run
        unsettled.find_each(batch_size: 100) do |cpt|
          ct = cpt.local_hcb_code&.canonical_transactions&.first

          if ct
            CanonicalPendingTransactionService::Settle.new(
              canonical_transaction: ct,
              canonical_pending_transaction: cpt
            ).run!
          end
        end
      end

      private

      def unsettled
        CanonicalPendingTransaction.unsettled.fee_revenue
      end

    end
  end
end
