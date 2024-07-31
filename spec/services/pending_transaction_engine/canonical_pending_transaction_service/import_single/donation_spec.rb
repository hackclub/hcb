# frozen_string_literal: true

require "rails_helper"

describe PendingTransactionEngine::CanonicalPendingTransactionService::ImportSingle::Donation do

  context "when passing a raw pending donation transaction that is not yet processed" do
    it "processes into a CanonicalPendingTransaction" do
      expect(RawPendingDonationTransaction.count).to eq(0)


      raw_pending_donation_transaction = create(:raw_pending_donation_transaction, date_posted: Date.current)

      expect do
        described_class.new(raw_pending_donation_transaction:).run
      end.to change { CanonicalPendingTransaction.count }.by(1)
    end
  end

  context "when passing a raw pending donation transaction that is already processed" do
    let(:raw_pending_donation_transaction) { create(:raw_pending_donation_transaction) }

    before do
      _processed_donation_canonical_pending_transaction = create(:canonical_pending_transaction, raw_pending_donation_transaction:)
    end

    it "ignores it when processing" do
      expect do
        described_class.new(raw_pending_donation_transaction:).run
      end.to change { CanonicalPendingTransaction.count }.by(0)
    end
  end

  context "attributes" do
    let(:raw_pending_donation_transaction) { create(:raw_pending_donation_transaction, date_posted: Date.current, amount_cents: 42) }

    before do
      raw_pending_donation_transaction
    end

    context "when processed" do
      it "copies the attributes and sets fronted to true" do
        expect do
          described_class.new(raw_pending_donation_transaction:).run
        end.to change { CanonicalPendingTransaction.count }.by(1)

        canonical_pending_transaction = CanonicalPendingTransaction.last
        expect(canonical_pending_transaction.date).to eq(raw_pending_donation_transaction.date_posted)
        expect(canonical_pending_transaction.memo).to eq(raw_pending_donation_transaction.memo)
        expect(canonical_pending_transaction.amount_cents).to eq(raw_pending_donation_transaction.amount_cents)
        expect(canonical_pending_transaction.fronted).to eq(true)
      end
    end
  end
end
