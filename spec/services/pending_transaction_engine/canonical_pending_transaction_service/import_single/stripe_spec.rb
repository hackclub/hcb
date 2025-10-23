# frozen_string_literal: true

require "rails_helper"

describe PendingTransactionEngine::CanonicalPendingTransactionService::ImportSingle::Stripe do

  context "when passing a raw pending stripe transaction that is not yet processed" do
    it "processes into a CanonicalPendingTransaction" do
      raw_pending_stripe_transaction = create(
        :raw_pending_stripe_transaction,
        stripe_merchant_category: "bakeries",
        date_posted: Date.current
      )

      expect do
        described_class.new(raw_pending_stripe_transaction:).run
      end.to change { CanonicalPendingTransaction.count }.by(1)

      cpt = raw_pending_stripe_transaction.reload.canonical_pending_transaction
      expect(cpt).to be_present
      expect(cpt.category.slug).to eq("food-fun")
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
        expect(canonical_pending_transaction.category.slug).to eq("food-fun")
      end
    end
  end
end
