# frozen_string_literal: true

require "rails_helper"

RSpec.describe FeeReimbursementService::CreateCanonicalPendingTransaction, type: :service do
  # The pending transaction is mapped to the Hack Club Bank event, which must
  # exist for the service to succeed.
  let!(:hack_club_bank) { Event.find_by(id: EventMappingEngine::EventIds::HACK_CLUB_BANK) || create(:event, id: EventMappingEngine::EventIds::HACK_CLUB_BANK) }

  let(:fee_reimbursement) { create(:fee_reimbursement, amount: 12_34) }

  subject(:run) { described_class.new(fee_reimbursement_id: fee_reimbursement.id).run }

  describe "#run" do
    it "creates a raw pending fee reimbursement transaction (as an expense)" do
      run
      rpfrt = fee_reimbursement.reload.raw_pending_fee_reimbursement_transaction

      expect(rpfrt).to be_present
      expect(rpfrt.amount_cents).to eq(-fee_reimbursement.amount)
    end

    it "creates a linked canonical pending transaction and returns it" do
      canonical_pending_transaction = run

      expect(canonical_pending_transaction).to be_present
      expect(canonical_pending_transaction.amount_cents).to eq(-fee_reimbursement.amount)
      expect(canonical_pending_transaction.raw_pending_fee_reimbursement_transaction)
        .to eq(fee_reimbursement.reload.raw_pending_fee_reimbursement_transaction)
    end

    it "categorizes the pending transaction as stripe-fee-reimbursements" do
      canonical_pending_transaction = run

      expect(canonical_pending_transaction.category.slug).to eq("stripe-fee-reimbursements")
      expect(canonical_pending_transaction.category_mapping.assignment_strategy).to eq("automatic")
    end

    it "maps the pending transaction to the Hack Club Bank event" do
      expect(run.event).to eq(hack_club_bank)
    end

    it "is idempotent — re-running does not create a second pending transaction" do
      first = run
      second = described_class.new(fee_reimbursement_id: fee_reimbursement.id).run

      expect(second).to eq(first)
      expect(RawPendingFeeReimbursementTransaction.where(fee_reimbursement_id: fee_reimbursement.id).count).to eq(1)
      expect(CanonicalPendingTransaction.fee_reimbursement.count).to eq(1)
    end

    it "does nothing for a zero-amount reimbursement" do
      zero = create(:fee_reimbursement, amount: 0)

      result = described_class.new(fee_reimbursement_id: zero.id).run

      expect(result).to be_nil
      expect(zero.reload.raw_pending_fee_reimbursement_transaction).to be_nil
    end

    # Regression test: creating a fresh (and inevitably unmapped) Ledger::Item
    # for a reimbursement whose top-up already settled, instead of finding
    # the settled transaction's existing one.
    context "when the reimbursement's top-up already settled" do
      it "does nothing when the settled transaction embeds the weekly short code" do
        old = create(:fee_reimbursement, amount: 12_34, processed_at: 18.months.ago)
        weekly_hcb_code = HcbCode.create!(hcb_code: "HCB-900-#{old.processed_at.strftime("%G_%V")}")
        create(:canonical_transaction, memo: "HCBCLB HCB-#{weekly_hcb_code.short_code}", amount_cents: -1234)

        result = described_class.new(fee_reimbursement_id: old.id).run

        expect(result).to be_nil
        expect(old.reload.raw_pending_fee_reimbursement_transaction).to be_nil
      end

      it "does nothing when settlement crossed into the next ISO week (no short code, old memo format)" do
        old = create(:fee_reimbursement, amount: 12_34, processed_at: Time.utc(2025, 1, 10, 12, 0, 0)) # Friday
        create(:canonical_transaction, memo: "HCKCLB FEE REIMBU", amount_cents: -1234, date: Date.new(2025, 1, 13)) # following Monday

        result = described_class.new(fee_reimbursement_id: old.id).run

        expect(result).to be_nil
        expect(old.reload.raw_pending_fee_reimbursement_transaction).to be_nil
      end

      it "still creates the pending transaction when nothing has settled yet" do
        old = create(:fee_reimbursement, amount: 12_34, processed_at: 18.months.ago)

        result = described_class.new(fee_reimbursement_id: old.id).run

        expect(result).to be_present
        expect(old.reload.raw_pending_fee_reimbursement_transaction).to be_present
      end
    end
  end

  describe "weekly grouping" do
    # Fee reimbursements group weekly under HCB-900-<ISO week> (unlike the
    # per-record codes of fee revenue / stripe service fees). We assert the two
    # deterministic pieces: (1) the pending transaction lands on that weekly code,
    # and (2) a settled transaction bearing the pending transaction's short code
    # reuses its ledger item.
    it "groups the pending transaction under the weekly HCB-900 code" do
      canonical_pending_transaction = run

      expected = [
        TransactionGroupingEngine::Calculate::HcbCode::HCB_CODE,
        TransactionGroupingEngine::Calculate::HcbCode::OUTGOING_FEE_REIMBURSEMENT_CODE,
        canonical_pending_transaction.date.strftime("%G_%V")
      ].join(TransactionGroupingEngine::Calculate::HcbCode::SEPARATOR)

      expect(canonical_pending_transaction.hcb_code).to eq(expected)
    end

    it "shares its ledger item with a settled transaction carrying the same short code" do
      canonical_pending_transaction = run
      pending_ledger_item = canonical_pending_transaction.ledger_item
      expect(pending_ledger_item).to be_present

      canonical_transaction = create(:canonical_transaction, memo: "HCB-#{pending_ledger_item.short_code}")

      expect(canonical_transaction.reload.ledger_item).to eq(pending_ledger_item)
    end
  end
end
