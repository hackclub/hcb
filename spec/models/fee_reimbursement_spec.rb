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

  describe "#settled_fee_reimbursement_transaction" do
    it "is nil when the reimbursement hasn't been processed yet" do
      unprocessed = create(:fee_reimbursement, processed_at: nil)

      expect(unprocessed.settled_fee_reimbursement_transaction).to be_nil
    end

    it "is nil when nothing has settled for that week" do
      fr = create(:fee_reimbursement, amount: 12_34, processed_at: 18.months.ago)

      expect(fr.settled_fee_reimbursement_transaction).to be_nil
    end

    it "finds the settled transaction by the weekly HCB-900 short code, regardless of its own date" do
      fr = create(:fee_reimbursement, amount: 12_34, processed_at: 18.months.ago)
      weekly_hcb_code = HcbCode.create!(hcb_code: "HCB-900-#{fr.processed_at.strftime("%G_%V")}")
      settled = create(:canonical_transaction, memo: "HCBCLB HCB-#{weekly_hcb_code.short_code}", amount_cents: -1234, date: Date.current)

      expect(fr.settled_fee_reimbursement_transaction).to eq(settled)
    end

    it "falls back to a week + amount match when the settled memo carries no short code" do
      # Pre-2025-05-18 memo format, settlement crossed into the next ISO week.
      fr = create(:fee_reimbursement, amount: 12_34, processed_at: Time.utc(2025, 1, 10, 12, 0, 0)) # Friday
      settled = create(:canonical_transaction, memo: "HCKCLB FEE REIMBU", amount_cents: -1234, date: Date.new(2025, 1, 13)) # Monday

      expect(fr.settled_fee_reimbursement_transaction).to eq(settled)
    end

    it "does not match a differently-sized settlement in the same window" do
      fr = create(:fee_reimbursement, amount: 12_34, processed_at: Time.utc(2025, 1, 10, 12, 0, 0))
      create(:canonical_transaction, memo: "HCKCLB FEE REIMBU", amount_cents: -9_999, date: Date.new(2025, 1, 13))

      expect(fr.settled_fee_reimbursement_transaction).to be_nil
    end
  end
end
