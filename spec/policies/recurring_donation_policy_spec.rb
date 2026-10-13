# frozen_string_literal: true

require "rails_helper"

RSpec.describe RecurringDonationPolicy, type: :policy do
  let(:canceled) { build(:recurring_donation, :canceled) }
  let(:active) { build(:recurring_donation) }

  describe "#restart?" do
    it "lets admins restart a canceled donation" do
      expect(described_class.new(create(:user, :make_admin), canceled).restart?).to be(true)
    end

    it "doesn't let admins restart a donation that's still going" do
      expect(described_class.new(create(:user, :make_admin), active).restart?).to be(false)
    end

    # Restarting charges the donor's card, so viewing it isn't enough.
    it "doesn't let auditors restart a donation" do
      expect(described_class.new(create(:user, :make_auditor), canceled).restart?).to be(false)
    end

    it "doesn't let donors restart a donation" do
      expect(described_class.new(nil, canceled).restart?).to be_falsey
    end
  end
end
