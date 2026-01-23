# frozen_string_literal: true

module PendingEventMappingEngine
  module Settle
    class IncomingDisbursementHcbCode
      def run
        unsettled.find_each(batch_size: 100) do |cpt|
          # 1. identify disbursement
          disbursement = cpt.disbursement
          Rails.error.unexpected("Disbursement not found for canonical pending transaction #{cpt.id}") unless disbursement
          next unless disbursement

          # 2. look up canonical transactions by amount (check both sides during migration)
          cts = disbursement.canonical_transactions.where(amount_cents: cpt.amount_cents)
          ct = cts.first

          next unless ct

          if cts.size > 1
            Rails.error.unexpected "Multiple settled transactions for canonical pending transaction #{cpt.id}"
          end

          # 3. mark no longer pending
          CanonicalPendingTransactionService::Settle.new(
            canonical_transaction: ct,
            canonical_pending_transaction: cpt
          ).run!
        end
      end

      private

      def unsettled
        CanonicalPendingTransaction.unsettled.incoming_disbursement
      end

    end
  end
end
