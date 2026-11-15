# frozen_string_literal: true

require "rails_helper"

# Receiptable#no_or_lost_receipt! can be called on either an HcbCode or its
# Ledger::Item (ReceiptablesController's RECEIPTABLE_TYPE_MAP explicitly
# allows Ledger::Item as a receiptable_type for #mark_no_or_lost). These specs
# hold CardLocking::ReceiptResolution.on_no_or_lost_receipt to the same
# standard regardless of which side triggers it.
#
# NOTE: ReceiptsController's RECEIPTABLE_TYPE_MAP also allows Ledger::Item for
# regular receipt uploads, and on_receipt_upsert/on_receipt_destroy had the
# identical is_a?(HcbCode) gate - fixed the same way here for consistency.
# HcbCode#receipts reads through the ledger item, so materialize_card_locking!'s
# card_locking_resolved_at sees a receipt uploaded to the ledger item; that's
# covered in spec/models/concerns/receiptable_spec.rb.
RSpec.describe CardLocking::ReceiptResolution do
  include_context "card locking charges"
  include ActiveJob::TestHelper

  let(:now) { Time.zone.parse("2026-10-10 12:00:00") }

  before { travel_to(now) }

  describe "on_no_or_lost_receipt" do
    it "freezes receipt_resolved_at when marked no/lost via the ledger item, same as via hcb_code" do
      hc = create_settled_card_charge(user:, settled_at: 12.days.ago)
      hc.update!(card_charge_settled_at: 12.days.ago, receipt_due_at: 12.days.ago + 7.days)

      hc.ledger_item.no_or_lost_receipt!

      expect(hc.reload.receipt_resolved_at).to be_within(1.second).of(now)
    end

    it "unlocks the cardholder when marked no/lost via the ledger item, same as via hcb_code" do
      hc = create_settled_card_charge(user:, settled_at: 10.days.ago)
      hc.update!(card_charge_settled_at: 10.days.ago, receipt_due_at: 1.day.ago) # overdue
      user.update!(cards_locked: true)
      Flipper.enable(:card_locking)

      perform_enqueued_jobs(only: User::UpdateCardLockingJob) { hc.ledger_item.no_or_lost_receipt! }

      expect(user.reload.cards_locked?).to be(false)
    end
  end
end
