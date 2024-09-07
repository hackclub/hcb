# frozen_string_literal: true

require "rails_helper"

describe RawPendingInvoiceTransaction do
  context "valid factory" do
    it "succeeds" do
      expect(build(:raw_pending_invoice_transaction)).to be_valid
    end
  end
end
