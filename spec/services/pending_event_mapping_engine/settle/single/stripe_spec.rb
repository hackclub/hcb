# frozen_string_literal: true

require "rails_helper"

RSpec.describe PendingEventMappingEngine::Settle::Single::Stripe do
  let(:stripe_card) { create(:stripe_card, :with_stripe_id) }
  let(:raw_pending_stripe_transaction) { create(:raw_pending_stripe_transaction, stripe_transaction_id: "iauth_1") }
  let!(:canonical_pending_transaction) { create(:canonical_pending_transaction, raw_pending_stripe_transaction:) }

  let(:capture_raw_stripe_transaction) do
    rst = create(:raw_stripe_transaction, stripe_card:)
    rst.update!(stripe_authorization_id: raw_pending_stripe_transaction.stripe_transaction_id)
    rst
  end
  let(:capture_canonical_transaction) do
    create(:canonical_transaction,
           transaction_source: capture_raw_stripe_transaction,
           hashed_transactions: [build(:hashed_transaction, :stripe, raw_stripe_transaction: capture_raw_stripe_transaction)])
  end

  let(:refund_raw_stripe_transaction) do
    rst = create(:raw_stripe_transaction, stripe_card:)
    rst.stripe_transaction["type"] = "refund"
    rst.save!
    rst.update!(stripe_authorization_id: raw_pending_stripe_transaction.stripe_transaction_id)
    rst
  end
  let(:refund_canonical_transaction) do
    create(:canonical_transaction,
           transaction_source: refund_raw_stripe_transaction,
           hashed_transactions: [build(:hashed_transaction, :stripe, raw_stripe_transaction: refund_raw_stripe_transaction)])
  end

  it "settles the canonical_pending_transaction to the charge's canonical_transaction" do
    described_class.new(canonical_transaction: capture_canonical_transaction).run

    canonical_pending_transaction.reload
    expect(canonical_pending_transaction.canonical_transactions).to eq([capture_canonical_transaction])
  end

  context "when the canonical_transaction is a refund" do
    it "does not settle the canonical_pending_transaction" do
      expect(refund_canonical_transaction.stripe_refund?).to eq(true)

      described_class.new(canonical_transaction: refund_canonical_transaction).run

      canonical_pending_transaction.reload
      expect(canonical_pending_transaction.canonical_pending_settled_mappings).to be_empty
    end
  end

  context "when the charge has already settled and is later refunded" do
    it "does not also settle the refund, leaving the charge as the only settled mapping" do
      described_class.new(canonical_transaction: capture_canonical_transaction).run
      described_class.new(canonical_transaction: refund_canonical_transaction).run

      canonical_pending_transaction.reload
      expect(canonical_pending_transaction.canonical_transactions).to eq([capture_canonical_transaction])
    end
  end
end
