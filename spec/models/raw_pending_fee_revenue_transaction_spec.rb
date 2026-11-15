# frozen_string_literal: true

require "rails_helper"

RSpec.describe RawPendingFeeRevenueTransaction, type: :model do
  # A raw pending fee revenue transaction requires a FeeRevenue (belongs_to), so
  # we build it through one rather than a dedicated factory — the same way
  # FeeRevenueService::CreateCanonicalPendingTransaction does.
  let(:fee_revenue) do
    create(:fee_revenue,
           amount_cents: 12_34,
           start: Date.current.beginning_of_month,
           end: Date.current.end_of_month)
  end
  let(:raw_pending_fee_revenue_transaction) do
    fee_revenue.create_raw_pending_fee_revenue_transaction!(
      date_posted: fee_revenue.end,
      amount_cents: fee_revenue.amount_cents
    )
  end

  it "is valid" do
    expect(raw_pending_fee_revenue_transaction).to be_valid
  end

  describe "#date" do
    it "returns the date_posted" do
      expect(raw_pending_fee_revenue_transaction.date).to eq(raw_pending_fee_revenue_transaction.date_posted)
      expect(raw_pending_fee_revenue_transaction.date).to eq(fee_revenue.end)
    end
  end

  describe "#memo" do
    it "describes the fee revenue period" do
      expect(raw_pending_fee_revenue_transaction.memo).to eq(
        "Fee revenue for #{fee_revenue.start.strftime("%-m/%-d")} to #{fee_revenue.end.strftime("%-m/%-d")}"
      )
    end
  end
end
