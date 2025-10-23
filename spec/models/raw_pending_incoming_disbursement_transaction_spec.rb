# frozen_string_literal: true

require "rails_helper"

describe RawPendingIncomingDisbursementTransaction do
  context "valid factory" do
    it "succeeds" do
      expect(build(:raw_pending_incoming_disbursement_transaction)).to be_valid
    end
  end
end
