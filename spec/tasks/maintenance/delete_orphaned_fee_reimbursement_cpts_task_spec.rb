# frozen_string_literal: true

require "rails_helper"

RSpec.describe Maintenance::DeleteOrphanedFeeReimbursementCptsTask do
  let!(:hack_club_bank) { Event.find_by(id: EventMappingEngine::EventIds::HACK_CLUB_BANK) || create(:event, id: EventMappingEngine::EventIds::HACK_CLUB_BANK) }

  # Builds the orphaned state the pre-fix backstop used to create — a CPT +
  # Ledger::Item — bypassing FeeReimbursementService::CreateCanonicalPendingTransaction,
  # since it now refuses to create this state in the first place.
  def create_orphaned_cpt(fee_reimbursement)
    rpfrt = fee_reimbursement.create_raw_pending_fee_reimbursement_transaction!(
      date_posted: fee_reimbursement.processed_at.to_date,
      amount_cents: -fee_reimbursement.amount
    )
    CanonicalPendingTransaction.create!(date: rpfrt.date, amount_cents: rpfrt.amount_cents, memo: rpfrt.memo, raw_pending_fee_reimbursement_transaction: rpfrt)
  end

  describe "#collection" do
    it "only includes reimbursements with a raw pending fee reimbursement transaction" do
      with_cpt = create(:fee_reimbursement, amount: 12_34, processed_at: 18.months.ago)
      create_orphaned_cpt(with_cpt)
      without_cpt = create(:fee_reimbursement, amount: 12_34, processed_at: 18.months.ago)

      expect(described_class.new.collection).to include(with_cpt)
      expect(described_class.new.collection).not_to include(without_cpt)
    end
  end

  describe "#process" do
    it "deletes the orphaned CPT chain and the now-empty ledger item" do
      fr = create(:fee_reimbursement, amount: 12_34, processed_at: Time.utc(2025, 1, 10, 12, 0, 0)) # Friday
      cpt = create_orphaned_cpt(fr)
      ledger_item = cpt.ledger_item
      create(:canonical_transaction, memo: "HCKCLB FEE REIMBU", amount_cents: -1234, date: Date.new(2025, 1, 13)) # settled, following week

      described_class.new.process(fr)

      expect(CanonicalPendingTransaction.exists?(cpt.id)).to be false
      expect(RawPendingFeeReimbursementTransaction.where(fee_reimbursement: fr)).not_to exist
      expect(Ledger::Item.exists?(ledger_item.id)).to be false
    end

    it "leaves the reimbursement alone when its CPT isn't actually orphaned" do
      fr = create(:fee_reimbursement, amount: 12_34, processed_at: 18.months.ago)
      cpt = create_orphaned_cpt(fr)

      described_class.new.process(fr)

      expect(CanonicalPendingTransaction.exists?(cpt.id)).to be true
    end

    it "deletes the CPT but leaves the ledger item alone if it has other content attached" do
      fr = create(:fee_reimbursement, amount: 12_34, processed_at: Time.utc(2025, 1, 10, 12, 0, 0))
      cpt = create_orphaned_cpt(fr)
      ledger_item = cpt.ledger_item
      create(:canonical_transaction, memo: "HCKCLB FEE REIMBU", amount_cents: -1234, date: Date.new(2025, 1, 13))
      # Something else already settled onto this exact (erroneous) ledger item —
      # leave it alone rather than guessing which side is "correct".
      create(:canonical_transaction, ledger_item:)

      described_class.new.process(fr)

      expect(CanonicalPendingTransaction.exists?(cpt.id)).to be false
      expect(Ledger::Item.exists?(ledger_item.id)).to be true
    end

    it "is a no-op the second time it's run for the same reimbursement" do
      fr = create(:fee_reimbursement, amount: 12_34, processed_at: Time.utc(2025, 1, 10, 12, 0, 0))
      create_orphaned_cpt(fr)
      create(:canonical_transaction, memo: "HCKCLB FEE REIMBU", amount_cents: -1234, date: Date.new(2025, 1, 13))

      described_class.new.process(fr)
      expect { described_class.new.process(fr) }.not_to raise_error
    end
  end
end
