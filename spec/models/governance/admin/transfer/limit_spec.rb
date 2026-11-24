# frozen_string_literal: true

require "rails_helper"

RSpec.describe Governance::Admin::Transfer::Limit, type: :model do
  let(:limit) { create(:governance_admin_transfer_limit, amount_cents: 200_000_00) }

  describe "#effective_amount_cents" do
    it "is the usual amount when there are no boosts" do
      expect(limit.boost_amount_cents).to eq(0)
      expect(limit.effective_amount_cents).to eq(200_000_00)
    end

    it "adds active boosts" do
      create(:governance_admin_transfer_limit_boost, limit:, amount_cents: 1_000_000_00)
      create(:governance_admin_transfer_limit_boost, limit:, amount_cents: 50_000_00)

      expect(limit.boost_amount_cents).to eq(1_050_000_00)
      expect(limit.effective_amount_cents).to eq(1_250_000_00)
    end

    it "ignores expired boosts" do
      create(:governance_admin_transfer_limit_boost, limit:, amount_cents: 1_000_000_00, duration_in_hours: 24)

      travel 25.hours do
        expect(limit.effective_amount_cents).to eq(200_000_00)
      end
    end

    it "ignores other limits' boosts" do
      create(:governance_admin_transfer_limit_boost, amount_cents: 1_000_000_00)

      expect(limit.effective_amount_cents).to eq(200_000_00)
    end
  end

  describe "#remaining_amount_cents" do
    it "includes active boosts" do
      create(:governance_admin_transfer_limit_boost, limit:, amount_cents: 1_000_000_00)

      expect(limit.remaining_amount_cents).to eq(1_200_000_00)
    end
  end
end
