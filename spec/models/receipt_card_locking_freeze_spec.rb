# frozen_string_literal: true

require "rails_helper"

RSpec.describe Receipt, type: :model do
  include_context "card locking charges"
  include ActiveJob::TestHelper

  let(:now) { Time.zone.parse("2026-10-10 12:00:00") }

  before { travel_to(now) }

  describe "resolving a charge" do
    it "takes a due charge out of the overdue pile when a receipt is attached" do
      charge = create_settled_card_charge(user:, settled_at: 10.days.ago)
      charge.update!(receipt_due_at: 1.day.ago)

      attach_receipt(charge, uploaded_by: user)

      expect(charge.reload).not_to be_missing_receipt
      expect(user.card_locking_overdue_charges(now:)).not_to include(charge)
    end

    it "takes a due charge out of the overdue pile when it is marked no/lost" do
      charge = create_settled_card_charge(user:, settled_at: 12.days.ago)
      charge.update!(receipt_due_at: 12.days.ago + 7.days)

      charge.no_or_lost_receipt!

      expect(charge.reload).not_to be_missing_receipt
      expect(user.card_locking_overdue_charges(now:)).not_to include(charge)
    end
  end

  describe "deleting a receipt" do
    it "restarts the 7-day countdown from the deletion when the last receipt is deleted" do
      charge = create_settled_card_charge(user:, settled_at: 60.days.ago, uploaded_at: 59.days.ago)
      charge.update!(receipt_due_at: 53.days.ago)
      receipt = charge.receipts.sole

      receipt.destroy!

      expect(charge.reload.receipt_due_at).to be_within(1.second).of(now + 7.days)
      expect(user.card_locking_overdue_charges(now:)).to be_empty
      expect(user.card_locking_overdue_charges(now: now + 7.days + 1.minute)).to include(charge)
    end

    it "keeps the restarted countdown through the sweep" do
      charge = create_settled_card_charge(user:, settled_at: 60.days.ago, uploaded_at: 59.days.ago)
      charge.update!(receipt_due_at: 53.days.ago)
      charge.receipts.sole.destroy!

      UserService::RefreshReceiptDeadlines.new(user:, now: now + 1.hour).run

      expect(charge.reload.receipt_due_at).to be_within(1.second).of(now + 7.days)
    end

    it "keeps a later deadline the charge already had" do
      charge = create_settled_card_charge(user:, settled_at: 1.day.ago)
      receipt = attach_receipt(charge, uploaded_by: user)
      charge.update!(receipt_due_at: 10.days.from_now)

      receipt.destroy!

      expect(charge.reload.receipt_due_at).to be_within(1.second).of(10.days.from_now)
    end

    it "leaves the deadline alone when another receipt remains" do
      charge = create_settled_card_charge(user:, settled_at: 60.days.ago, uploaded_at: 59.days.ago)
      attach_receipt(charge, uploaded_by: user, at: 58.days.ago)
      charge.update!(receipt_due_at: 53.days.ago)

      charge.receipts.order(:created_at).first.destroy!

      expect(charge.reload.receipt_due_at).to be_within(1.second).of(53.days.ago)
      expect(charge).not_to be_missing_receipt
    end

    it "leaves the deadline alone when a lost receipt statement remains on file" do
      allow(CloudflareBrowserRun).to receive(:pdf).and_return("%PDF-1.4")
      charge = create_settled_card_charge(user:, settled_at: 60.days.ago, uploaded_at: 59.days.ago)
      statement = LostReceipt::Statement.new(date: Date.current, merchant: "Test Merchant", purpose: "Supplies", signer_name: user.full_name, confirmed: true,
                                             items_attributes: [{ description: "Notebooks", quantity: 1, unit_amount_cents: 10_00 }])
      expect(statement.submit(receiptable: charge.hcb_code)).to eq(true)
      statement.attach_pdf!
      charge.update!(receipt_due_at: 53.days.ago)

      charge.receipts.where.not(id: statement.receipt).sole.destroy!

      expect(charge.reload.receipt_due_at).to be_within(1.second).of(53.days.ago)
      expect(charge).not_to be_missing_receipt
    end

    # A no/lost mark without a statement is legacy data; losing its last receipt clears it.
    it "restarts the countdown when the last receipt of a charge marked no/lost without a statement is deleted" do
      charge = create_settled_card_charge(user:, settled_at: 60.days.ago, uploaded_at: 59.days.ago)
      charge.no_or_lost_receipt!
      charge.update!(receipt_due_at: 53.days.ago)

      charge.receipts.sole.destroy!

      expect(charge.reload).to be_missing_receipt
      expect(charge.receipt_due_at).to be_within(1.second).of(now + 7.days)
    end

    it "sets no deadline for a cardholder in no rollout stage" do
      Flipper.disable(:card_locking_enabled_on_07_17_2026, user)
      charge = create_settled_card_charge(user:, settled_at: 60.days.ago, uploaded_at: 59.days.ago)

      charge.receipts.sole.destroy!

      expect(charge.reload.receipt_due_at).to be_nil
    end
  end

  describe "synchronous unlock on receipt upload" do
    before do
      Flipper.enable(:card_locking)
    end

    it "unlocks the card on the receipt-upload path when the last overdue charge is resolved" do
      hc = create_settled_card_charge(user:, settled_at: 10.days.ago)
      hc.update!(receipt_due_at: 1.day.ago) # overdue
      user.update!(cards_locked: true)

      perform_enqueued_jobs(only: User::UpdateCardLockingJob) { attach_receipt(hc, uploaded_by: user) }

      expect(user.reload.cards_locked?).to be(false)
    end

    it "does NOT unlock while another charge is still overdue" do
      overdue = create_settled_card_charge(user:, settled_at: 12.days.ago)
      overdue.update!(receipt_due_at: 2.days.ago)
      target = create_settled_card_charge(user:, settled_at: 11.days.ago)
      target.update!(receipt_due_at: 1.day.ago)
      user.update!(cards_locked: true)

      perform_enqueued_jobs(only: User::UpdateCardLockingJob) { attach_receipt(target, uploaded_by: user) }

      expect(user.reload.cards_locked?).to be(true) # overdue keeps it locked
    end
  end

  describe "a resolved charge's deadline" do
    it "stays unchanged across re-materialization and the sweep" do
      charge = create_settled_card_charge(user:, settled_at: 5.days.ago)
      charge.update!(receipt_due_at: 5.days.ago + 7.days)
      attach_receipt(charge, uploaded_by: user)
      due_at = charge.reload.receipt_due_at

      charge.materialize_card_locking!(now: now + 1.hour)
      UserService::RefreshReceiptDeadlines.new(user:, now: now + 1.hour).run

      expect(charge.reload.receipt_due_at).to eq(due_at)
    end
  end
end
