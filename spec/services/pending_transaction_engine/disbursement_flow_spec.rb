# frozen_string_literal: true

require "rails_helper"

RSpec.describe PendingTransactionEngine do

  # TODO: move this method into business logic and use in view as well as this test
  def incoming_deposits(event)
    event.canonical_pending_transactions.incoming.unsettled.sum(:amount_cents)
  end

  context "disbursement moves pending money" do
    it "creates valid setup data" do
      source_event = create(:event)
      destination_event = create(:event)
      disbursement = create(:disbursement)

      expect(source_event).to be_valid
      expect(destination_event).to be_valid
      expect(disbursement).to be_valid
    end

    it "creates raw incoming and outgoing transactions" do
      source_event = create(:event)
      destination_event = create(:event)
      disbursement = create(:disbursement, event: destination_event, source_event:)

      expect(disbursement.raw_pending_incoming_disbursement_transaction).to be_nil
      expect(disbursement.raw_pending_outgoing_disbursement_transaction).to be_nil

      cpt_count = CanonicalPendingTransaction.count

      # Act
      ::PendingTransactionEngine::RawPendingIncomingDisbursementTransactionService::Disbursement::Import.new.run
      ::PendingTransactionEngine::RawPendingOutgoingDisbursementTransactionService::Disbursement::Import.new.run

      ::PendingTransactionEngine::CanonicalPendingTransactionService::Import::IncomingDisbursement.new.run
      ::PendingTransactionEngine::CanonicalPendingTransactionService::Import::OutgoingDisbursement.new.run

      # Assert
      disbursement.reload
      expect(disbursement.raw_pending_incoming_disbursement_transaction).to be_present
      expect(disbursement.raw_pending_outgoing_disbursement_transaction).to be_present

      expect(CanonicalPendingTransaction.count).to eq(cpt_count + 2)
    end

    it "increments the incoming deposit total" do
      source_event = create(:event)
      destination_event = create(:event)
      disbursement = create(:disbursement, event: destination_event, source_event:)

      incoming_amount_before = incoming_deposits destination_event

      ::PendingTransactionEngine::RawPendingIncomingDisbursementTransactionService::Disbursement::Import.new.run
      ::PendingTransactionEngine::RawPendingOutgoingDisbursementTransactionService::Disbursement::Import.new.run

      ::PendingTransactionEngine::CanonicalPendingTransactionService::Import::IncomingDisbursement.new.run
      ::PendingTransactionEngine::CanonicalPendingTransactionService::Import::OutgoingDisbursement.new.run

      ::PendingEventMappingEngine::Map::IncomingDisbursement.new.run
      ::PendingEventMappingEngine::Map::OutgoingDisbursement.new.run
      ::PendingEventMappingEngine::Settle::IncomingDisbursementHcbCode.new.run
      ::PendingEventMappingEngine::Settle::OutgoingDisbursementHcbCode.new.run
      ::PendingEventMappingEngine::Decline::IncomingDisbursement.new.run
      ::PendingEventMappingEngine::Decline::OutgoingDisbursement.new.run

      expect(incoming_deposits(destination_event)).to eq(incoming_amount_before + disbursement.amount)

      # TODO: should we assert that the source_event has been decremented 100?
    end
  end
end
