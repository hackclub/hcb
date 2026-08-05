# frozen_string_literal: true

require "rails_helper"

RSpec.describe PendingEventMappingEngine::Settle::Stripe do
  let(:stripe_card) { create(:stripe_card, :with_stripe_id) }
  let(:raw_pending_stripe_transaction) { create(:raw_pending_stripe_transaction, stripe_transaction_id: "iauth_1") }
  let!(:canonical_pending_transaction) { create(:canonical_pending_transaction, raw_pending_stripe_transaction:) }

  let!(:capture_raw_stripe_transaction) do
    rst = create(:raw_stripe_transaction, stripe_card:)
    rst.update!(stripe_authorization_id: raw_pending_stripe_transaction.stripe_transaction_id)
    rst
  end
  let!(:capture_canonical_transaction) do
    create(:canonical_transaction,
           transaction_source: capture_raw_stripe_transaction,
           hashed_transactions: [build(:hashed_transaction, :stripe, raw_stripe_transaction: capture_raw_stripe_transaction)])
  end

  let!(:refund_raw_stripe_transaction) do
    rst = create(:raw_stripe_transaction, stripe_card:)
    rst.stripe_transaction["type"] = "refund"
    rst.save!
    rst.update!(stripe_authorization_id: raw_pending_stripe_transaction.stripe_transaction_id)
    rst
  end
  let!(:refund_canonical_transaction) do
    create(:canonical_transaction,
           transaction_source: refund_raw_stripe_transaction,
           hashed_transactions: [build(:hashed_transaction, :stripe, raw_stripe_transaction: refund_raw_stripe_transaction)])
  end

  it "settles the canonical_pending_transaction to the charge's canonical_transaction only, skipping the refund" do
    described_class.new.run

    canonical_pending_transaction.reload
    expect(canonical_pending_transaction.canonical_transactions).to eq([capture_canonical_transaction])
    expect(canonical_pending_transaction.canonical_transactions).to_not include(refund_canonical_transaction)
  end
end
