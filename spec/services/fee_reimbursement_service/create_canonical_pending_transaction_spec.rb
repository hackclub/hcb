# frozen_string_literal: true

require "rails_helper"

RSpec.describe FeeReimbursementService::CreateCanonicalPendingTransaction, type: :service do
  # The pending transaction is mapped to the Hack Club Bank event, which must
  # exist for the service to succeed.
  let!(:hack_club_bank) { create(:event, id: EventMappingEngine::EventIds::HACK_CLUB_BANK) }

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
