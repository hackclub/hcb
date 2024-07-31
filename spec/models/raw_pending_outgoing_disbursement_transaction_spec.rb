# frozen_string_literal: true

require "rails_helper"

describe RawPendingOutgoingDisbursementTransaction do
  context "valid factory" do
    it "succeeds" do
      expect(build(:raw_pending_outgoing_disbursement_transaction)).to be_valid
    end
  end
end
