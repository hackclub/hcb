# frozen_string_literal: true

require "rails_helper"

RSpec.describe RawPendingFeeReimbursementTransaction, type: :model do
  # A raw pending fee reimbursement transaction requires a FeeReimbursement
  # (belongs_to), so we build it through one rather than a dedicated factory —
  # the same way FeeReimbursementService::CreateCanonicalPendingTransaction does.
  let(:fee_reimbursement) { create(:fee_reimbursement, amount: 12_34) }
  let(:raw_pending_fee_reimbursement_transaction) do
    fee_reimbursement.create_raw_pending_fee_reimbursement_transaction!(
      date_posted: Date.current,
      amount_cents: -fee_reimbursement.amount
    )
  end

  it "is valid" do
    expect(raw_pending_fee_reimbursement_transaction).to be_valid
  end

  describe "#date" do
    it "returns the date_posted" do
      expect(raw_pending_fee_reimbursement_transaction.date)
        .to eq(raw_pending_fee_reimbursement_transaction.date_posted)
    end
  end

  describe "#memo" do
    it "references the fee reimbursement and carries the weekly-grouping trigger" do
      expect(raw_pending_fee_reimbursement_transaction.memo).to eq("Fee reimbursement ##{fee_reimbursement.id}")
      # The grouping engine keys fee reimbursements off this substring.
      expect(raw_pending_fee_reimbursement_transaction.memo.downcase).to include("fee reimburse")
    end
  end
end
