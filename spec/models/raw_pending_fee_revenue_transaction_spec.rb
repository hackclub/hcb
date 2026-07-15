# frozen_string_literal: true

require "rails_helper"

RSpec.describe RawPendingFeeRevenueTransaction, type: :model do
  # A raw pending fee revenue transaction is always created by its FeeRevenue
  # (it requires one via belongs_to), so we source it that way rather than
  # through a dedicated factory. The mapping needs the Hack Club Bank event.
  let!(:hack_club_bank) { create(:event, id: EventMappingEngine::EventIds::HACK_CLUB_BANK) }
  let(:fee_revenue) do
    create(:fee_revenue,
           amount_cents: 12_34,
           start: Date.current.beginning_of_month,
           end: Date.current.end_of_month)
  end
  let(:raw_pending_fee_revenue_transaction) { fee_revenue.raw_pending_fee_revenue_transaction }

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
