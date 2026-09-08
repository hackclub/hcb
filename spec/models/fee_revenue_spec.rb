# frozen_string_literal: true

require "rails_helper"

RSpec.describe FeeRevenue, type: :model do
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

  it "eagerly creates its hcb code" do
    expect(fee_revenue.local_hcb_code).to be_present
    expect(fee_revenue.hcb_code).to eq("HCB-#{TransactionGroupingEngine::Calculate::HcbCode::FEE_REVENUE_CODE}-#{fee_revenue.id}")
  end

  # Creation of the pending transaction is handled by
  # FeeRevenueService::CreateCanonicalPendingTransaction — see its spec.
end
