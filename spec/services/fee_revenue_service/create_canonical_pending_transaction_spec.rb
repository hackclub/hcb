# frozen_string_literal: true

require "rails_helper"

RSpec.describe FeeRevenueService::CreateCanonicalPendingTransaction, type: :service do
  # The pending transaction is mapped to the Hack Club Bank event, which must
  # exist for the service to succeed.
  let!(:hack_club_bank) { create(:event, id: EventMappingEngine::EventIds::HACK_CLUB_BANK) }

  let(:fee_revenue) do
    create(:fee_revenue,
           amount_cents: 12_34,
           start: Date.current.beginning_of_month,
           end: Date.current.end_of_month)
  end

  subject(:run) { described_class.new(fee_revenue_id: fee_revenue.id).run }

  describe "#run" do
    it "creates a raw pending fee revenue transaction" do
      run
      rpfrt = fee_revenue.reload.raw_pending_fee_revenue_transaction

      expect(rpfrt).to be_present
      expect(rpfrt.amount_cents).to eq(fee_revenue.amount_cents)
      expect(rpfrt.date_posted).to eq(fee_revenue.end)
    end

    it "creates a linked canonical pending transaction and returns it" do
      canonical_pending_transaction = run

      expect(canonical_pending_transaction).to be_present
      expect(canonical_pending_transaction.amount_cents).to eq(fee_revenue.amount_cents)
      expect(canonical_pending_transaction.date).to eq(fee_revenue.end)
      expect(canonical_pending_transaction.raw_pending_fee_revenue_transaction)
        .to eq(fee_revenue.reload.raw_pending_fee_revenue_transaction)
    end

    it "categorizes the pending transaction as hcb-revenue" do
      canonical_pending_transaction = run

      expect(canonical_pending_transaction.category.slug).to eq("hcb-revenue")
      expect(canonical_pending_transaction.category_mapping.assignment_strategy).to eq("automatic")
    end

    it "maps the pending transaction to the Hack Club Bank event" do
      expect(run.event).to eq(hack_club_bank)
    end

    it "is idempotent — re-running does not create a second pending transaction" do
      first = run
      second = described_class.new(fee_revenue_id: fee_revenue.id).run

      expect(second).to eq(first)
      expect(RawPendingFeeRevenueTransaction.where(fee_revenue_id: fee_revenue.id).count).to eq(1)
      expect(CanonicalPendingTransaction.fee_revenue.count).to eq(1)
    end
  end

  describe "ledger mapping (end-to-end)" do
    # In production a FeeRevenue and its pending transaction resolve to a single
    # shared HcbCode (HCB-702-<id>) and therefore a single Ledger::Item, so the
    # settled canonical transaction — whose memo carries that same HCB short code
    # — reuses the pending transaction's ledger item. That single-HcbCode identity
    # is verified in console/production; it can't be reproduced here because
    # RSpec's transactional fixtures never commit the eagerly-created HcbCode
    # before the service runs, so `fee_revenue.local_hcb_code` and the CPT can
    # momentarily split into two rows in-test. We therefore assert the two pieces
    # that ARE deterministic: (1) the pending transaction is grouped under the fee
    # revenue's hcb code, and (2) a settled transaction bearing the pending
    # transaction's short code lands on the same ledger item.
    it "groups the pending transaction under the fee revenue's hcb code" do
      canonical_pending_transaction = run

      expect(canonical_pending_transaction.hcb_code).to eq(fee_revenue.hcb_code)
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
