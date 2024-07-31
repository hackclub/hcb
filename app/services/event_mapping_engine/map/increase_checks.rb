# frozen_string_literal: true

module EventMappingEngine
  module Map
    class IncreaseChecks
      def run
        likely_increase_checks.each do |ct|
          increase_check = ct.increase_check
          next unless increase_check

          ::CanonicalEventMapping.create!(canonical_transaction: ct, event: increase_check.event)
        end
      end

      private

      def likely_increase_checks
        ::CanonicalTransaction.unmapped.likely_increase_checks.order("date asc") +
          ::CanonicalTransaction.unmapped.with_column_transaction_type("check.incoming_debit")
      end

    end
  end
end
