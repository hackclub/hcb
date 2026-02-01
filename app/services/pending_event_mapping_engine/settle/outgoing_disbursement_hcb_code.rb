# frozen_string_literal: true

module PendingEventMappingEngine
  module Settle
    class OutgoingDisbursementHcbCode
      def run
        unsettled.find_each(batch_size: 100) do |cpt|
          # 1. identify disbursement
          disbursement = cpt.outgoing_disbursement
          Rails.error.unexpected("Disbursement not found for canonical pending transaction #{cpt.id}") unless disbursement
          next unless disbursement

          # 2. look up canonical transactions by hcb & amount
          cts = disbursement.local_hcb_code.canonical_transactions.where(amount_cents: cpt.amount_cents)
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
        CanonicalPendingTransaction.unsettled.outgoing_disbursement
      end

    end
  end
end
