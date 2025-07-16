# frozen_string_literal: true

module PendingEventMappingEngine
  module Settle
    class OutgoingCheck
      def run
        unsettled.find_each(batch_size: 100) do |cpt|
          # 1. identify check
          check = cpt.check
          Airbrake.notify("Check not found for canonical pending transaction #{cpt.id}") unless check
          next unless check

          event = check.event

          # 2. look up canonical - scoped to event for added accuracy
          cts = event.canonical_transactions.where("memo ilike ? and date >= ?", "#{ActiveRecord::Base.sanitize_sql_like(check.check_number.to_s)} CHECK%", cpt.date).order("date asc")

          next if cts.count < 1 # no match found yet. not processed.

          Airbrake.notify("matched more than 1 canonical transaction for check_number #{check.check_number}") if cts.count > 1
          ct = cts.first

          # 3. mark no longer pending
          CanonicalPendingTransactionService::Settle.new(
            canonical_transaction: ct,
            canonical_pending_transaction: cpt
          ).run!
        end
      end

      private

      def unsettled
        CanonicalPendingTransaction.unsettled.outgoing_check
      end

    end
  end
end
