# frozen_string_literal: true

require "rails_helper"

RSpec.describe FeeReimbursement, type: :model do
  describe ".missing_pending_transaction" do
    it "excludes unprocessed reimbursements" do
      unprocessed = create(:fee_reimbursement, processed_at: nil)

      expect(FeeReimbursement.missing_pending_transaction).not_to include(unprocessed)
    end

    it "includes processed reimbursements that still lack a raw pending fee reimbursement transaction" do
      processed = create(:fee_reimbursement, processed_at: 1.day.ago)

      expect(FeeReimbursement.missing_pending_transaction).to include(processed)
    end

    it "excludes processed reimbursements that already have one, unlike the legacy .pending scope" do
      processed = create(:fee_reimbursement, processed_at: 18.months.ago)
      processed.create_raw_pending_fee_reimbursement_transaction!(date_posted: processed.processed_at.to_date, amount_cents: -processed.amount)

      expect(FeeReimbursement.missing_pending_transaction).not_to include(processed)
      # The legacy scope is broken for this purpose: it never excludes anything,
      # because it keys off the dead pre-2021 `transactions` table.
      expect(FeeReimbursement.pending).to include(processed)
    end
  end
end
