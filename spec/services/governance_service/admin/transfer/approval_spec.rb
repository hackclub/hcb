# frozen_string_literal: true

require "rails_helper"

RSpec.describe GovernanceService::Admin::Transfer::Approval do
  let(:admin) { create(:user, :make_admin) }
  let!(:limit) { create(:governance_admin_transfer_limit, user: admin, amount_cents: 200_000_00) }

  def approve(amount_cents)
    described_class.new(transfer: create(:disbursement), amount_cents:, user: admin).run
  end

  it "denies a transfer over the usual limit" do
    expect(approve(1_000_000_00)).to eq(false)

    attempt = limit.approval_attempts.last
    expect(attempt).to be_denied_for_insufficient_limit
    expect(attempt.current_limit_boost_amount_cents).to eq(0)
  end

  context "with an active boost" do
    before { create(:governance_admin_transfer_limit_boost, limit:, amount_cents: 1_000_000_00) }

    it "approves a transfer covered by the boost, and keeps the usual limit available" do
      expect(approve(1_000_000_00)).to eq(true)

      attempt = limit.approval_attempts.last
      expect(attempt).to be_approved
      expect(attempt.current_limit_amount_cents).to eq(200_000_00)
      expect(attempt.current_limit_boost_amount_cents).to eq(1_000_000_00)
      expect(attempt.current_limit_effective_amount_cents).to eq(1_200_000_00)

      expect(approve(200_000_00)).to eq(true)
      expect(approve(1_00)).to eq(false)
    end

    it "states the boosted limit when denying" do
      expect(approve(1_200_000_01)).to eq(false)

      expect(limit.approval_attempts.last.denial_message).to include("$1,200,000.00")
    end
  end

  it "stops counting the boost once it expires" do
    create(:governance_admin_transfer_limit_boost, limit:, amount_cents: 1_000_000_00, duration_in_hours: 24)

    travel 25.hours do
      expect(approve(1_000_000_00)).to eq(false)
    end
  end
end
