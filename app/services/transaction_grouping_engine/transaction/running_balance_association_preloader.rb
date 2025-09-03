# frozen_string_literal: true

module TransactionGroupingEngine
  module Transaction
    class RunningBalanceAssociationPreloader
      def initialize(transactions:, event:)
        @transactions = transactions
        @event = event
      end

      def run!
        preload_associations!
      end

      def preload_associations!
        hcb_code_codes = @transactions.map(&:hcb_code)
        included_models = [:receipts, :comments,
                           { canonical_transactions: :canonical_event_mapping },
                           { canonical_pending_transactions: [:event, :canonical_pending_declined_mapping] }]
        included_models << :tags
        hcb_code_objects = HcbCode
                           .includes(included_models)
                           .where(hcb_code: hcb_code_codes)
        hcb_code_by_code = hcb_code_objects.index_by(&:hcb_code)

        @transactions.each do |t|
          t.local_hcb_code = hcb_code_by_code[t.hcb_code]
        end
      end

    end
  end
end
