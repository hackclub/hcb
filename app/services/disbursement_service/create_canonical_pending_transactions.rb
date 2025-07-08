# frozen_string_literal: true

module DisbursementService
  class CreateCanonicalPendingTransactions
    def initialize(disbursement:, fronted: false)
      @disbursement = disbursement
      @fronted = fronted
    end

    def run
      return if @disbursement.canonical_pending_transactions.any?

      # 1. Create the raw pending transactions
      rpodt = ::PendingTransactionEngine::RawPendingOutgoingDisbursementTransactionService::Disbursement::ImportSingle.new(disbursement: @disbursement).run
      # 2. Canonize the newly added raw pending transactions
      o_cpt = ::PendingTransactionEngine::CanonicalPendingTransactionService::ImportSingle::OutgoingDisbursement.new(raw_pending_outgoing_disbursement_transaction: rpodt).run
      # 3. Map to event
      ::PendingEventMappingEngine::Map::Single::OutgoingDisbursement.new(canonical_pending_transaction: o_cpt).run
      # 4. Front if required
      o_cpt.update(fronted: @fronted)

      if @disbursement.scheduled_on.nil?
        # We only want to import Incoming Disbursements AFTER the scheduled date

        # 1. Create the raw pending transactions
        rpidt = ::PendingTransactionEngine::RawPendingIncomingDisbursementTransactionService::Disbursement::ImportSingle.new(disbursement: @disbursement).run
        # 2. Canonize the newly added raw pending transactions
        i_cpt = ::PendingTransactionEngine::CanonicalPendingTransactionService::ImportSingle::IncomingDisbursement.new(raw_pending_incoming_disbursement_transaction: rpidt).run
        # 3. Map to event
        ::PendingEventMappingEngine::Map::Single::IncomingDisbursement.new(canonical_pending_transaction: i_cpt).run
        # 4. Front if required
        i_cpt.update(fronted: @fronted)
      end

    end

  end
end
