# frozen_string_literal: true

module EventMappingEngine
  module Map
    class Achs
      def run
        likely_column_achs.each do |ct|
          ach_transfer = ct.ach_transfer
          next unless ach_transfer

          ::CanonicalEventMapping.create!(canonical_transaction: ct, event: ach_transfer.event)
        end
      end

      private

      def likely_column_achs
        ::CanonicalTransaction.unmapped.with_column_transaction_type("ach.outgoing_transfer")
      end

    end
  end
end
