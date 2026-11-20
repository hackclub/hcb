# frozen_string_literal: true

require "rails_helper"

describe PendingTransactionEngine::CanonicalPendingTransactionService::Import::Stripe do

  context "when there is a pending stripe transaction ready for processing" do
    it "processes into a CanonicalPendingTransaction" do
      expect(RawPendingStripeTransaction.count).to eq(0)

      raw_pending_stripe_transaction = create(:raw_pending_stripe_transaction,
                                              date_posted: Date.current)

      expect do
        described_class.new.run
      end.to change { CanonicalPendingTransaction.count }.by(1)
    end
  end

  context "when there are previously processed raw pending stripe transactions" do
    let(:raw_pending_stripe_transaction) { create(:raw_pending_stripe_transaction, date_posted: Date.current) }

    let!(:canonical_pending_transaction) do
      create(:canonical_pending_transaction, raw_pending_stripe_transaction:, amount_cents: raw_pending_stripe_transaction.amount_cents)
    end

    it "skips it when processing" do
      expect(PendingTransactionEngine::CanonicalPendingTransactionService::ImportSingle::Stripe).not_to receive(:new)

      described_class.new.run
    end

    it "re-imports it when the raw amount no longer matches" do
      raw_pending_stripe_transaction.update!(amount_cents: canonical_pending_transaction.amount_cents + 100)

      expect do
        described_class.new.run
      end.not_to(change { CanonicalPendingTransaction.count })

      expect(canonical_pending_transaction.reload.amount_cents).to eq(raw_pending_stripe_transaction.amount_cents)
    end

    context "when there are also ready to process raw pending stripe transactions" do
      it "processes into a CanonicalPendingTransaction" do
        new_stripe_transaction = create(:raw_pending_stripe_transaction,
                                        date_posted: Date.current,
                                        amount_cents: 1000)

        expect(RawPendingStripeTransaction.count).to eq(2)

        expect do
          described_class.new.run
        end.to change { CanonicalPendingTransaction.count }.by(1)

        pending_transaction = CanonicalPendingTransaction.last
        expect(pending_transaction.raw_pending_stripe_transaction_id).to eq(new_stripe_transaction.id)
        expect(pending_transaction.amount_cents).to eq(new_stripe_transaction.amount_cents)
      end
    end
  end

end
