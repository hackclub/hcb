# frozen_string_literal: true

require "rails_helper"

describe PendingTransactionEngine::CanonicalPendingTransactionService::Import::OutgoingAch do
  let(:event) { create(:event) }

  let(:ach_transfer) {
    create(:ach_transfer,
           event:,
           amount: 1000,
           aasm_state: "deposited",
           recipient_email: "example@example.com",

           # A workaround to avoid that the ach_transfer record creates its own raw_pending_outgoing_ach_transaction
           # and canonical_pending_transaction record when running the `after_create` callback.
           scheduled_on: Date.current + 1.day)
  }

  before do
    # Create enough balance to cover the ach_transfer amount. Otherwise, the transfer will fail create validation.
    _incoming_transaction = create(:canonical_transaction, event:, amount_cents: 1000)
  end


  context "when there is a pending outgoing ach transaction ready for processing" do
    it "processes into a CanonicalPendingTransaction" do
      expect(RawPendingOutgoingAchTransaction.count).to eq(0)

      raw_pending_outgoing_ach_transaction = create(:raw_pending_outgoing_ach_transaction,
                                                    date_posted: Date.current,
                                                    ach_transfer:)

      expect do
        described_class.new.run
      end.to change { CanonicalPendingTransaction.count }.by(1)
    end
  end

  context "when there are previously processed raw pending outgoing ach transactions" do
    let(:raw_pending_outgoing_ach_transaction) { create(:raw_pending_outgoing_ach_transaction, ach_transfer:) }

    before do
      _processed_outgoing_ach_canonical_pending_transaction = create(:canonical_pending_transaction,
                                                                     raw_pending_outgoing_ach_transaction: )
    end

    it "ignores it when processing" do
      expect do
        described_class.new.run
      end.to change { CanonicalPendingTransaction.count }.by(0)
    end

    context "when there are also ready to process raw pending outgoing ach transactions" do
      it "processes into a CanonicalPendingTransaction" do
        new_ach_transfer = create(:ach_transfer,
                                  event:,
                                  amount: 1000,
                                  aasm_state: "deposited",
                                  recipient_email: "example1@example.com",
                                  scheduled_on: Date.current + 1.day )


        new_ach_transaction = create(:raw_pending_outgoing_ach_transaction,
                                     date_posted: Date.current,
                                     ach_transfer: new_ach_transfer)

        expect(RawPendingOutgoingAchTransaction.count).to eq(2)

        expect do
          described_class.new.run
        end.to change { CanonicalPendingTransaction.count }.by(1)

        pending_transaction = CanonicalPendingTransaction.last
        expect(pending_transaction.raw_pending_outgoing_ach_transaction_id).to eq(new_ach_transaction.id)
        expect(pending_transaction.amount_cents).to eq(new_ach_transaction.amount_cents)
      end
    end
  end
end
