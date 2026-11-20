# frozen_string_literal: true

require "rails_helper"

# Card-locking state lives on the charge's Ledger::Item, and the service only
# ever sees items. A no/lost mark can still be made on the transaction's HCB
# code (ReceiptablesController's RECEIPTABLE_TYPE_MAP allows HcbCode for
# #mark_no_or_lost): Receiptable#sync_no_or_lost_receipt! copies the mark onto
# the item, whose own column hook (CardLocking::ChargeBehavior) brings it here.
# Receipts attach to the item; that path is covered in
# spec/models/receipt_card_locking_freeze_spec.rb.
RSpec.describe CardLocking::ReceiptResolution do
  include_context "card locking charges"
  include ActiveJob::TestHelper

  let(:now) { Time.zone.parse("2026-10-10 12:00:00") }

  before { travel_to(now) }

  describe "marking a charge no/lost" do
    it "resolves the charge and takes it out of the overdue pile" do
      charge = create_settled_card_charge(user:, settled_at: 12.days.ago)
      charge.update!(receipt_due_at: 12.days.ago + 7.days)

      charge.no_or_lost_receipt!

      expect(charge.reload).not_to be_missing_receipt
      expect(Ledger::Item.receipt_overdue(now)).not_to include(charge)
    end

    it "unlocks the cardholder" do
      charge = create_settled_card_charge(user:, settled_at: 10.days.ago)
      charge.update!(receipt_due_at: 1.day.ago) # overdue
      user.update!(cards_locked: true)
      Flipper.enable(:card_locking)

      perform_enqueued_jobs(only: User::UpdateCardLockingJob) { charge.no_or_lost_receipt! }

      expect(user.reload.cards_locked?).to be(false)
    end

    it "reaches the item, and unlocks the cardholder, when the mark is made on the HCB code" do
      charge = create_settled_card_charge(user:, settled_at: 10.days.ago)
      charge.update!(receipt_due_at: 1.day.ago) # overdue
      user.update!(cards_locked: true)
      Flipper.enable(:card_locking)

      perform_enqueued_jobs(only: User::UpdateCardLockingJob) { charge.hcb_code.no_or_lost_receipt! }

      expect(charge.reload).not_to be_missing_receipt
      expect(Ledger::Item.receipt_overdue(now)).not_to include(charge)
      expect(user.reload.cards_locked?).to be(false)
    end

    it "does nothing for an HCB code with no ledger item" do
      orphan = create(:hcb_code)

      expect { orphan.no_or_lost_receipt! }.not_to have_enqueued_job(User::UpdateCardLockingJob)
    end
  end

  describe "on_receipt_upsert" do
    it "ignores a receipt on anything but a ledger item" do
      receipt = Receipt.new(receiptable: create(:reimbursement_expense))

      expect { described_class.on_receipt_upsert(receipt) }.not_to have_enqueued_job(User::UpdateCardLockingJob)
    end
  end
end
