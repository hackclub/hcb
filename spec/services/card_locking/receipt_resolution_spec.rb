# frozen_string_literal: true

require "rails_helper"

# Card-locking state lives on the charge's Ledger::Item, but
# Receiptable#no_or_lost_receipt! can still be called on its HcbCode
# (ReceiptablesController's RECEIPTABLE_TYPE_MAP allows HcbCode as a
# receiptable_type for #mark_no_or_lost). These specs hold
# CardLocking::ReceiptResolution.on_no_or_lost_receipt to the same standard
# whichever side triggers it. Receipts themselves are attached to the item;
# that path is covered in spec/models/receipt_card_locking_freeze_spec.rb.
RSpec.describe CardLocking::ReceiptResolution do
  include_context "card locking charges"
  include ActiveJob::TestHelper

  let(:now) { Time.zone.parse("2026-10-10 12:00:00") }

  before { travel_to(now) }

  describe "on_no_or_lost_receipt" do
    it "freezes receipt_resolved_at when marked no/lost via the HCB code, same as via the ledger item" do
      charge = create_settled_card_charge(user:, settled_at: 12.days.ago)
      charge.update!(receipt_due_at: 12.days.ago + 7.days)

      charge.hcb_code.no_or_lost_receipt!

      expect(charge.reload.receipt_resolved_at).to be_within(1.second).of(now)
    end

    it "unlocks the cardholder when marked no/lost via the HCB code, same as via the ledger item" do
      charge = create_settled_card_charge(user:, settled_at: 10.days.ago)
      charge.update!(receipt_due_at: 1.day.ago) # overdue
      user.update!(cards_locked: true)
      Flipper.enable(:card_locking)

      perform_enqueued_jobs(only: User::UpdateCardLockingJob) { charge.hcb_code.no_or_lost_receipt! }

      expect(user.reload.cards_locked?).to be(false)
    end

    it "does nothing for an HCB code with no ledger item" do
      orphan = create(:hcb_code)

      expect { described_class.on_no_or_lost_receipt(orphan) }.not_to have_enqueued_job(User::UpdateCardLockingJob)
    end
  end
end
