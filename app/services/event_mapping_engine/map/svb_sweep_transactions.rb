# frozen_string_literal: true

module EventMappingEngine
  module Map
    class SvbSweepTransactions
      def run
        svb_sweep_transactions.find_each(batch_size: 100) do |ct|
          attrs = {
            canonical_transaction_id: ct.id,
            event_id: EventMappingEngine::EventIds::SVB_SWEEPS
          }
          ::CanonicalEventMapping.create!(attrs)
        end
      end

      private

      def svb_sweep_transactions
        ::CanonicalTransaction.unmapped.to_svb_sweep_account
                              .or(::CanonicalTransaction.unmapped.from_svb_sweep_account)
                              .or(::CanonicalTransaction.unmapped.hcb_sweep)
                              .or(::CanonicalTransaction.unmapped.svb_sweep_account)
                              .order("date asc")
      end

    end
  end
end
