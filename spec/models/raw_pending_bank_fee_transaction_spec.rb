# frozen_string_literal: true

require "rails_helper"

describe "RawPendingBankFeeTransaction" do
  context "valid factory" do
    it "succeeds" do
      expect(build(:raw_pending_bank_fee_transaction)).to be_valid
    end
  end
end
