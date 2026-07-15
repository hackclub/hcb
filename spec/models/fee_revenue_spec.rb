# frozen_string_literal: true

require "rails_helper"

RSpec.describe FeeRevenue, type: :model do
  # The pending transaction is mapped to the Hack Club Bank event, which must
  # exist for the after_create_commit callback to succeed.
  let!(:hack_club_bank) { create(:event, id: EventMappingEngine::EventIds::HACK_CLUB_BANK) }

  let(:fee_revenue) do
    create(:fee_revenue,
           amount_cents: 12_34,
           start: Date.current.beginning_of_month,
           end: Date.current.end_of_month)
  end

  it "is valid" do
    expect(fee_revenue).to be_valid
  end

  it "starts in the pending state" do
    expect(fee_revenue).to be_pending
  end

  describe "creating the pending transaction (after_create_commit)" do
    let(:raw_pending_fee_revenue_transaction) do
      fee_revenue.raw_pending_fee_revenue_transaction
    end
    let(:canonical_pending_transaction) do
      raw_pending_fee_revenue_transaction.reload.canonical_pending_transaction
    end

    it "creates a raw pending fee revenue transaction" do
      expect(raw_pending_fee_revenue_transaction).to be_present
      expect(raw_pending_fee_revenue_transaction.amount_cents).to eq(fee_revenue.amount_cents)
      expect(raw_pending_fee_revenue_transaction.date_posted).to eq(fee_revenue.end)
    end

    it "creates a linked canonical pending transaction" do
      expect(canonical_pending_transaction).to be_present
      expect(canonical_pending_transaction.amount_cents).to eq(fee_revenue.amount_cents)
      expect(canonical_pending_transaction.date).to eq(fee_revenue.end)
    end

    it "categorizes the pending transaction as hcb-revenue" do
      expect(canonical_pending_transaction.category.slug).to eq("hcb-revenue")
      expect(canonical_pending_transaction.category_mapping.assignment_strategy).to eq("automatic")
    end

    it "maps the pending transaction to the Hack Club Bank event" do
      expect(canonical_pending_transaction.event).to eq(hack_club_bank)
    end
  end

  describe "ledger mapping (end-to-end)" do
    let(:canonical_pending_transaction) do
      fee_revenue.raw_pending_fee_revenue_transaction.reload.canonical_pending_transaction
    end

    # A settled canonical transaction is matched to the fee revenue by the short
    # code encoded in its memo (HCB-<short_code>). It should land on the very
    # same ledger item as the pending transaction created on FeeRevenue create.
    let(:canonical_transaction) do
      create(:canonical_transaction, memo: "HCB-#{fee_revenue.local_hcb_code.short_code}")
    end

    it "shares one ledger item between the pending and settled transactions" do
      pending_ledger_item = canonical_pending_transaction.ledger_item
      expect(pending_ledger_item).to be_present

      expect(canonical_transaction.reload.ledger_item).to eq(pending_ledger_item)
    end
  end
end
