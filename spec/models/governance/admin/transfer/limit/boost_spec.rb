# frozen_string_literal: true

require "rails_helper"

RSpec.describe Governance::Admin::Transfer::Limit::Boost, type: :model do
  describe "duration" do
    it "defaults to 36 hours" do
      freeze_time do
        boost = create(:governance_admin_transfer_limit_boost)

        expect(boost.expires_at).to eq(36.hours.from_now)
      end
    end

    it "sets expires_at from duration_in_hours" do
      freeze_time do
        boost = create(:governance_admin_transfer_limit_boost, duration_in_hours: 48)

        expect(boost.expires_at).to eq(48.hours.from_now)
      end
    end

    it "must last at least as long as the limit window" do
      boost = build(:governance_admin_transfer_limit_boost, duration_in_hours: 23)

      expect(boost).not_to be_valid
      expect(boost.errors[:duration_in_hours]).to be_present
    end

    it "can last exactly as long as the limit window" do
      expect(build(:governance_admin_transfer_limit_boost, duration_in_hours: 24)).to be_valid
    end

    it "must last at most a week" do
      expect(build(:governance_admin_transfer_limit_boost, duration_in_hours: 7 * 24)).to be_valid
      expect(build(:governance_admin_transfer_limit_boost, duration_in_hours: (7 * 24) + 1)).not_to be_valid
    end
  end

  it "requires a positive amount" do
    expect(build(:governance_admin_transfer_limit_boost, amount_cents: 0)).not_to be_valid
    expect(build(:governance_admin_transfer_limit_boost, amount_cents: -1)).not_to be_valid
  end

  it "requires a reason" do
    expect(build(:governance_admin_transfer_limit_boost, reason: "")).not_to be_valid
  end

  describe ".active" do
    it "includes only boosts that haven't expired" do
      active = create(:governance_admin_transfer_limit_boost)
      expired = create(:governance_admin_transfer_limit_boost)
      expired.update!(expires_at: 1.minute.ago)

      expect(described_class.active).to contain_exactly(active)
      expect(active).to be_active
      expect(expired).not_to be_active
    end
  end

  describe "#revoke!" do
    it "expires the boost immediately" do
      boost = create(:governance_admin_transfer_limit_boost)

      boost.revoke!

      expect(boost).not_to be_active
      expect(described_class.active).not_to include(boost)
    end
  end
end
