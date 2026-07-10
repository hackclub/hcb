# frozen_string_literal: true

require "rails_helper"

RSpec.describe Receipt, type: :model do
  include_context "card locking charges"
  include ActiveJob::TestHelper

  let(:now) { Time.zone.parse("2026-10-10 12:00:00") }

  before { travel_to(now) }

  describe "freezing receipt_resolved_at" do
    it "freezes receipt_resolved_at when a receipt is attached to a chargeable, due charge" do
      hc = create_settled_card_charge(user:, settled_at: 5.days.ago)
      hc.update!(receipt_settled_at: 5.days.ago, receipt_due_at: 5.days.ago + 7.days)

      attach_receipt(hc, uploaded_by: user)

      expect(hc.reload.receipt_resolved_at).to be_within(1.second).of(now)
    end

    it "freezes receipt_resolved_at at the mark time when marked no/lost after the deadline" do
      hc = create_settled_card_charge(user:, settled_at: 12.days.ago)
      hc.update!(receipt_settled_at: 12.days.ago, receipt_due_at: 12.days.ago + 7.days)

      hc.no_or_lost_receipt!

      expect(hc.reload.receipt_resolved_at).to be_within(1.second).of(now)
    end

    it "resets receipt_resolved_at to nil when the last receipt is destroyed" do
      hc = create_settled_card_charge(user:, settled_at: 5.days.ago)
      hc.update!(receipt_settled_at: 5.days.ago, receipt_due_at: 5.days.ago + 7.days)
      receipt = attach_receipt(hc, uploaded_by: user)
      expect(hc.reload.receipt_resolved_at).to be_present

      receipt.destroy!

      expect(hc.reload.receipt_resolved_at).to be_nil
    end
  end

  describe "synchronous unlock on receipt upload" do
    before do
      Flipper.enable(:card_locking_2025_06_09, user)
    end

    it "unlocks the card on the receipt-upload path when the last overdue charge is resolved" do
      hc = create_settled_card_charge(user:, settled_at: 10.days.ago)
      hc.update!(receipt_settled_at: 10.days.ago, receipt_due_at: 1.day.ago) # overdue
      user.update!(cards_locked: true)

      perform_enqueued_jobs(only: User::UpdateCardLockingJob) { attach_receipt(hc, uploaded_by: user) }

      expect(user.reload.cards_locked?).to be(false)
    end

    it "does NOT unlock while another charge is still overdue" do
      overdue = create_settled_card_charge(user:, settled_at: 12.days.ago)
      overdue.update!(receipt_settled_at: 12.days.ago, receipt_due_at: 2.days.ago)
      target = create_settled_card_charge(user:, settled_at: 11.days.ago)
      target.update!(receipt_settled_at: 11.days.ago, receipt_due_at: 1.day.ago)
      user.update!(cards_locked: true)

      perform_enqueued_jobs(only: User::UpdateCardLockingJob) { attach_receipt(target, uploaded_by: user) }

      expect(user.reload.cards_locked?).to be(true) # overdue keeps it locked
    end
  end

  describe "immutability of a resolved receipt_resolved_at" do
    it "leaves receipt_resolved_at unchanged across re-materialization and the sweep" do
      hc = create_settled_card_charge(user:, settled_at: 5.days.ago)
      hc.update!(receipt_settled_at: 5.days.ago, receipt_due_at: 5.days.ago + 7.days)
      attach_receipt(hc, uploaded_by: user)
      resolved_at = hc.reload.receipt_resolved_at
      expect(resolved_at).to be_present

      hc.materialize_card_locking!(now: now + 1.hour)
      UserService::RefreshReceiptDeadlines.new(user:, now: now + 1.hour).run

      expect(hc.reload.receipt_resolved_at).to eq(resolved_at)
    end
  end
end
