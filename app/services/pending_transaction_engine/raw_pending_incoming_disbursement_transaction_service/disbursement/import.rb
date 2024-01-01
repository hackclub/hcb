# frozen_string_literal: true

module PendingTransactionEngine
  module RawPendingIncomingDisbursementTransactionService
    module Disbursement
      class Import
        def run
          disbursements.find_each(batch_size: 100) do |disbursement|
            ImportSingle.new(disbursement:).run
          end
        end

        private

        def disbursements
          ::Disbursement.in_transit.or(::Disbursement.reviewing.where(scheduled__on: nil)).where.missing :raw_pending_incoming_disbursement_transaction
        end

      end
    end
  end
end
