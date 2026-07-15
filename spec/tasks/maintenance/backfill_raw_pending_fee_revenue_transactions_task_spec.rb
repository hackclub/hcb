# frozen_string_literal: true

require "rails_helper"

RSpec.describe Maintenance::BackfillRawPendingFeeRevenueTransactionsTask do
  let!(:hcb_event) { Event.find_by(id: EventMappingEngine::EventIds::HACK_CLUB_BANK) || create(:event, id: EventMappingEngine::EventIds::HACK_CLUB_BANK) }
  let(:fee_revenue) { create(:fee_revenue) }

  it "creates a raw pending transaction, canonical pending transaction, and event mapping" do
    described_class.new.process(fee_revenue)

    raw_pending_fee_revenue_transaction = fee_revenue.raw_pending_fee_revenue_transaction
    expect(raw_pending_fee_revenue_transaction).to be_present
    expect(raw_pending_fee_revenue_transaction.amount_cents).to eq(fee_revenue.amount_cents)

    canonical_pending_transaction = raw_pending_fee_revenue_transaction.canonical_pending_transaction
    expect(canonical_pending_transaction).to be_present
    expect(canonical_pending_transaction.hcb_code).to eq(fee_revenue.hcb_code)
    expect(canonical_pending_transaction.event).to eq(hcb_event)
    expect(canonical_pending_transaction).not_to be_settled
  end

  it "is idempotent" do
    2.times { described_class.new.process(FeeRevenue.find(fee_revenue.id)) }

    expect(RawPendingFeeRevenueTransaction.where(fee_revenue_transaction_id: fee_revenue.id.to_s).count).to eq(1)
    expect(CanonicalPendingTransaction.fee_revenue.count).to eq(1)
  end

  it "skips and reports fee revenues with missing data" do
    fee_revenue.update_column(:amount_cents, nil)

    expect(Rails.error).to receive(:report).with(instance_of(described_class::AnomalyError))
    described_class.new.process(fee_revenue.reload)

    expect(RawPendingFeeRevenueTransaction.count).to eq(0)
  end

  it "settles against the canonical transaction when it exists" do
    canonical_transaction = create(:canonical_transaction, memo: "HCB-#{fee_revenue.local_hcb_code.short_code}", amount_cents: fee_revenue.amount_cents)
    expect(canonical_transaction.reload.hcb_code).to eq(fee_revenue.hcb_code)

    described_class.new.process(fee_revenue)

    canonical_pending_transaction = CanonicalPendingTransaction.fee_revenue.last
    expect(canonical_pending_transaction.canonical_transactions).to include(canonical_transaction)
    expect(canonical_pending_transaction).to be_settled
  end
end
