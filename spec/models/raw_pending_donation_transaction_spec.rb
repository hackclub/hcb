# frozen_string_literal: true

require "rails_helper"

describe RawPendingDonationTransaction do
  context "valid factory" do
    it "succeeds" do
      expect(build(:raw_pending_donation_transaction)).to be_valid
    end
  end
end
