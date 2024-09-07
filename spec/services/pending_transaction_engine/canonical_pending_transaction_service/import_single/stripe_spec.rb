# frozen_string_literal: true

require "rails_helper"

describe PendingTransactionEngine::CanonicalPendingTransactionService::ImportSingle::Stripe do

  context "when passing a raw pending stripe transaction that is not yet processed" do
    it "processes into a CanonicalPendingTransaction" do
      expect(RawPendingStripeTransaction.count).to eq(0)


      raw_pending_stripe_transaction = create(:raw_pending_stripe_transaction,
                                              date_posted: Date.current)

      expect do
        described_class.new(raw_pending_stripe_transaction:).run
      end.to change { CanonicalPendingTransaction.count }.by(1)
    end
  end

  context "when passing a raw pending stripe transaction that is already processed" do
    let(:raw_pending_stripe_transaction) { create(:raw_pending_stripe_transaction, date_posted: Date.current) }

    before do
      _processed_stripe_canonical_pending_transaction = create(:canonical_pending_transaction, raw_pending_stripe_transaction:)
    end

    it "ignores it when processing" do
      expect do
        described_class.new(raw_pending_stripe_transaction:).run
      end.to change { CanonicalPendingTransaction.count }.by(0)
    end
  end

  context "attributes" do
    let(:raw_pending_stripe_transaction) {
      create(:raw_pending_stripe_transaction, date_posted: Date.current)
    }

    before do
      raw_pending_stripe_transaction
    end

    context "when processed" do
      it "copies the attributes over to the pending canonical transaction" do
        expect do
          described_class.new(raw_pending_stripe_transaction:).run
        end.to change { CanonicalPendingTransaction.count }.by(1)

        canonical_pending_transaction = CanonicalPendingTransaction.last
        expect(canonical_pending_transaction.date).to eq(raw_pending_stripe_transaction.date_posted)
        expect(canonical_pending_transaction.memo).to eq(raw_pending_stripe_transaction.memo)
        expect(canonical_pending_transaction.amount_cents).to eq(raw_pending_stripe_transaction.amount_cents)
      end
    end
  end
end
