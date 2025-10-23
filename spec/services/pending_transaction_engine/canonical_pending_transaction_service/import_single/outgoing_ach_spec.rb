# frozen_string_literal: true

require "rails_helper"

describe PendingTransactionEngine::CanonicalPendingTransactionService::ImportSingle::OutgoingAch do
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


  context "when passing a raw pending ach transaction that is not yet processed" do
    it "processes into a CanonicalPendingTransaction" do
      expect(RawPendingOutgoingAchTransaction.count).to eq(0)

      raw_pending_outgoing_ach_transaction = create(:raw_pending_outgoing_ach_transaction,
                                                    date_posted: Date.current,
                                                    ach_transfer:)


      expect do
        described_class.new(raw_pending_outgoing_ach_transaction:).run
      end.to change { CanonicalPendingTransaction.count }.by(1)
    end
  end

  context "attributes" do
    let(:raw_pending_outgoing_ach_transaction) {
      create(:raw_pending_outgoing_ach_transaction,
             date_posted: Date.current,
             ach_transfer:,
             amount_cents: 1000)
    }

    before do
      raw_pending_outgoing_ach_transaction
    end

    context "when processed" do
      it "copies the attributes to the canonical pending transaction" do
        expect do
          described_class.new(raw_pending_outgoing_ach_transaction:).run
        end.to change { CanonicalPendingTransaction.count }.by(1)

        canonical_pending_transaction = CanonicalPendingTransaction.last
        expect(canonical_pending_transaction.date).to eq(raw_pending_outgoing_ach_transaction.date_posted)
        expect(canonical_pending_transaction.memo).to eq(raw_pending_outgoing_ach_transaction.memo)
        expect(canonical_pending_transaction.amount_cents).to eq(raw_pending_outgoing_ach_transaction.amount_cents)
      end
    end
  end
end
