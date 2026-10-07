# frozen_string_literal: true

require "rails_helper"

RSpec.describe StripeServiceFeeService::CreateCanonicalPendingTransaction, type: :service do
  # The pending transaction is mapped to the Hack Club Bank event, which must
  # exist for the service to succeed.
  let!(:hack_club_bank) { create(:event, id: EventMappingEngine::EventIds::HACK_CLUB_BANK) }

  before do
    # StripeServiceFee creates a StripeTopup on create, which calls the Stripe API.
    stub_request(:post, "https://api.stripe.com/v1/topups")
      .to_return(status: 200, body: { id: "tu_1" }.to_json, headers: {})
  end

  let(:stripe_service_fee) do
    create(:stripe_service_fee, amount_cents: -12_34, stripe_description: "Test fee")
  end

  subject(:run) { described_class.new(stripe_service_fee_id: stripe_service_fee.id).run }

  describe "#run" do
    it "creates a raw pending stripe service fee transaction" do
      run
      rpssft = stripe_service_fee.reload.raw_pending_stripe_service_fee_transaction

      expect(rpssft).to be_present
      expect(rpssft.amount_cents).to eq(-stripe_service_fee.amount_cents)
      expect(rpssft.date_posted).to eq(stripe_service_fee.created_at.to_date)
    end

    it "creates a linked canonical pending transaction and returns it" do
      canonical_pending_transaction = run

      expect(canonical_pending_transaction).to be_present
      expect(canonical_pending_transaction.amount_cents).to eq(-stripe_service_fee.amount_cents)
      expect(canonical_pending_transaction.raw_pending_stripe_service_fee_transaction)
        .to eq(stripe_service_fee.reload.raw_pending_stripe_service_fee_transaction)
    end

    it "categorizes the pending transaction as stripe-service-fees" do
      canonical_pending_transaction = run

      expect(canonical_pending_transaction.category.slug).to eq("stripe-service-fees")
      expect(canonical_pending_transaction.category_mapping.assignment_strategy).to eq("automatic")
    end

    it "maps the pending transaction to the Hack Club Bank event" do
      expect(run.event).to eq(hack_club_bank)
    end

    it "is idempotent — re-running does not create a second pending transaction" do
      first = run
      second = described_class.new(stripe_service_fee_id: stripe_service_fee.id).run

      expect(second).to eq(first)
      expect(RawPendingStripeServiceFeeTransaction.where(stripe_service_fee_id: stripe_service_fee.id).count).to eq(1)
      expect(CanonicalPendingTransaction.stripe_service_fee.count).to eq(1)
    end
  end

  describe "ledger mapping (end-to-end)" do
    # In production a StripeServiceFee and its pending transaction resolve to a
    # single shared HcbCode (HCB-610-<id>) and therefore a single Ledger::Item, so
    # the settled canonical transaction — whose memo carries that same HCB short
    # code — reuses the pending transaction's ledger item. That single-HcbCode
    # identity can't be reproduced under RSpec's transactional fixtures (the
    # eagerly-created HcbCode isn't committed before the service runs), so we
    # assert the two deterministic pieces: (1) the pending transaction is grouped
    # under the stripe service fee's hcb code, and (2) a settled transaction
    # bearing the pending transaction's short code lands on the same ledger item.
    it "groups the pending transaction under the stripe service fee's hcb code" do
      canonical_pending_transaction = run

      expect(canonical_pending_transaction.hcb_code).to eq(stripe_service_fee.hcb_code)
    end

    it "shares its ledger item with a settled transaction carrying the same short code" do
      canonical_pending_transaction = run
      pending_ledger_item = canonical_pending_transaction.ledger_item
      expect(pending_ledger_item).to be_present

      canonical_transaction = create(:canonical_transaction, memo: "HCB-#{pending_ledger_item.short_code}")

      expect(canonical_transaction.reload.ledger_item).to eq(pending_ledger_item)
    end
  end
end
