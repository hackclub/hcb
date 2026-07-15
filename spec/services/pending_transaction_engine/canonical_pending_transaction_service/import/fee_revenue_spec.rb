# frozen_string_literal: true

require "rails_helper"

describe PendingTransactionEngine::CanonicalPendingTransactionService::Import::FeeRevenue do

  context "when there is a raw pending fee revenue transaction ready for processing" do
    it "processes into a CanonicalPendingTransaction" do
      expect(RawPendingFeeRevenueTransaction.count).to eq(0) # there are no previously processed raw pending fee revenue transactions

      raw_pending_fee_revenue_transaction = create(:raw_pending_fee_revenue_transaction)

      expect do
        described_class.new.run
      end.to change { CanonicalPendingTransaction.count }.by(1)

      pending_transaction = CanonicalPendingTransaction.last
      expect(pending_transaction.raw_pending_fee_revenue_transaction_id).to eq(raw_pending_fee_revenue_transaction.id)
      expect(pending_transaction.hcb_code).to eq(raw_pending_fee_revenue_transaction.fee_revenue.hcb_code)
      expect(pending_transaction.category&.slug).to eq("hcb-revenue")
    end
  end

  context "when there are previously processed raw pending fee revenue transactions" do
    before do
      raw_pending_fee_revenue_transaction = create(:raw_pending_fee_revenue_transaction)
      _processed_fee_revenue_canonical_pending_transaction = create(:canonical_pending_transaction, raw_pending_fee_revenue_transaction:)
    end

    it "ignores it when processing" do
      expect do
        described_class.new.run
      end.to change { CanonicalPendingTransaction.count }.by(0)
    end

    context "when there are also ready to process raw pending fee revenue transactions" do
      it "processes into a CanonicalPendingTransaction" do
        new_fee_revenue_transaction = create(:raw_pending_fee_revenue_transaction)
        expect(RawPendingFeeRevenueTransaction.count).to eq(2) # there is a processed and non processed fee revenue transaction

        expect do
          described_class.new.run
        end.to change { CanonicalPendingTransaction.count }.by(1)

        pending_transaction = CanonicalPendingTransaction.last
        expect(pending_transaction.raw_pending_fee_revenue_transaction_id).to eq(new_fee_revenue_transaction.id)
      end
    end
  end

  context "fronted" do
    let(:raw_pending_fee_revenue_transaction) {
      create(:raw_pending_fee_revenue_transaction, amount_cents:)
    }

    before do
      raw_pending_fee_revenue_transaction
    end

    context "when amount_cents is positive" do
      let(:amount_cents) { 100 }

      it "fronted is true" do
        expect do
          described_class.new.run
        end.to change { CanonicalPendingTransaction.count }.by(1)

        pending_transaction = CanonicalPendingTransaction.last
        expect(pending_transaction.amount_cents).to eq(amount_cents)
        expect(pending_transaction).to be_fronted
      end
    end

    context "when amount_cents is not-positive" do
      let(:amount_cents) { 0 }

      it "fronted is false" do
        expect do
          described_class.new.run
        end.to change { CanonicalPendingTransaction.count }.by(1)

        pending_transaction = CanonicalPendingTransaction.last
        expect(pending_transaction.amount_cents).to eq(amount_cents)
        expect(pending_transaction).to_not be_fronted
      end
    end
  end
end
