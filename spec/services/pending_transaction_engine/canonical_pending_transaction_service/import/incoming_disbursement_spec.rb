# frozen_string_literal: true

require "rails_helper"

describe PendingTransactionEngine::CanonicalPendingTransactionService::Import::IncomingDisbursement do

  context "when there is a pending incoming_disbursement transaction ready for processing" do
    it "processes into a CanonicalPendingTransaction" do
      expect(RawPendingIncomingDisbursementTransaction.count).to eq(0)

      raw_pending_incoming_disbursement_transaction = create(:raw_pending_incoming_disbursement_transaction,
                                                             date_posted: Date.current)

      expect do
        described_class.new.run
      end.to change { CanonicalPendingTransaction.count }.by(1)
    end
  end

  context "when there are previously processed raw pending incoming_disbursement transactions" do
    let(:raw_pending_incoming_disbursement_transaction) { create(:raw_pending_incoming_disbursement_transaction) }

    before do
      _processed_incoming_disbursement_canonical_pending_transaction = create(:canonical_pending_transaction,
                                                                              raw_pending_incoming_disbursement_transaction:)
    end

    it "ignores it when processing" do
      expect do
        described_class.new.run
      end.to change { CanonicalPendingTransaction.count }.by(0)
    end

    context "when there are also ready to process raw pending incoming_disbursement transactions" do
      it "processes into a CanonicalPendingTransaction" do
        new_incoming_disbursement = create(:raw_pending_incoming_disbursement_transaction,
                                           date_posted: Date.current,
                                           amount_cents: 1000)

        expect(RawPendingIncomingDisbursementTransaction.count).to eq(2)

        expect do
          described_class.new.run
        end.to change { CanonicalPendingTransaction.count }.by(1)

        pending_transaction = CanonicalPendingTransaction.last
        expect(pending_transaction.raw_pending_incoming_disbursement_transaction_id).to eq(new_incoming_disbursement.id)
        expect(pending_transaction.amount_cents).to eq(new_incoming_disbursement.amount_cents)
      end
    end
  end

end
