# frozen_string_literal: true

require "rails_helper"

describe "RawPendingFeeRevenueTransaction" do
  context "valid factory" do
    it "succeeds" do
      expect(build(:raw_pending_fee_revenue_transaction)).to be_valid
    end
  end

  it "generates a memo from the fee revenue's period" do
    fee_revenue = create(:fee_revenue, start: Date.new(2026, 7, 1), end: Date.new(2026, 7, 7))
    raw_pending_fee_revenue_transaction = create(:raw_pending_fee_revenue_transaction, fee_revenue:)

    expect(raw_pending_fee_revenue_transaction.memo).to eq("Fee revenue for 7/1 to 7/7")
  end

  it "likely maps to the HCB event" do
    expect(build(:raw_pending_fee_revenue_transaction).likely_event_id).to eq(EventMappingEngine::EventIds::HACK_CLUB_BANK)
  end
end
