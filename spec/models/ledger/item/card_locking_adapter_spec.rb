# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ledger::Item do
  include_context "card locking charges"

  let(:now) { Time.zone.parse("2026-10-10 12:00:00") }

  # Not `travel_to(now) { ex.run }`: that sets ActiveSupport's nested-block
  # guard, which then trips when `attach_receipt` below does its own
  # `travel_to(at) { ... }` to backdate a receipt upload.
  around do |ex|
    travel_to(now)
    ex.run
  ensure
    travel_back
  end

  describe "#card_locking_resolved_at" do
    it "is the first receipt's created_at when a receipt has been uploaded" do
      charge = create_settled_card_charge(user:, settled_at: 5.days.ago, uploaded_at: 2.days.ago)

      expect(charge.card_locking_resolved_at).to be_within(1.second).of(2.days.ago)
      expect(charge).to be_card_locking_resolved
    end

    it "is marked_no_or_lost_receipt_at when the charge was marked without a receipt" do
      charge = create_settled_card_charge(user:, settled_at: 5.days.ago)
      charge.update!(marked_no_or_lost_receipt_at: 1.day.ago)

      expect(charge.card_locking_resolved_at).to be_within(1.second).of(1.day.ago)
    end

    it "is nil for an unresolved charge" do
      charge = create_settled_card_charge(user:, settled_at: 5.days.ago)

      expect(charge.card_locking_resolved_at).to be_nil
      expect(charge).not_to be_card_locking_resolved
    end
  end

  describe "#materialize_card_locking!" do
    it "sets receipt_due_at on a fresh untrusted charge" do
      charge = create_settled_card_charge(user:, settled_at: 1.day.ago)

      charge.materialize_card_locking!(now:, trusted: false)

      expect(charge.receipt_due_at).to be_within(1.second).of(1.day.ago + 7.days)
    end

    it "sets no deadline for a cardholder in no rollout stage" do
      Flipper.disable(:card_locking_enabled_on_07_17_2026, user)
      charge = create_settled_card_charge(user:, settled_at: 1.day.ago)

      charge.materialize_card_locking!(now:, trusted: false)

      expect(charge.receipt_due_at).to be_nil
    end

    it "sets no deadline for a charge that settled before the cardholder's stage date" do
      charge = create_settled_card_charge(user:, settled_at: 1.day.ago)

      # A stage that starts after this charge settled: no deadline, can't lock.
      charge.materialize_card_locking!(now:, trusted: false, enforcement_start_date: (now + 1.day).to_date)

      expect(charge.receipt_due_at).to be_nil
    end

    it "slides receipt_due_at off the last settled charge when the cardholder is trusted" do
      charge = create_settled_card_charge(user:, settled_at: 3.days.ago)

      charge.materialize_card_locking!(now:, trusted: true, last_settled_charge_at: now - 1.hour)

      expect(charge.receipt_due_at).to be_within(1.second).of((now - 1.hour) + 7.days)
    end

    it "gives a charge that already has a receipt an unfloored settled_at + 7 days deadline" do
      charge = create_settled_card_charge(user:, settled_at: 30.days.ago, uploaded_at: 2.days.ago)
      charge.update_columns(receipt_due_at: nil)

      charge.materialize_card_locking!(now:, trusted: false)

      # Not pushed out to now + 72h: receipt_trusted? reads this as the late upload's deadline.
      expect(charge.receipt_due_at).to be_within(1.second).of(30.days.ago + 7.days)
    end

    it "never moves a future deadline earlier" do
      charge = create_settled_card_charge(user:, settled_at: 1.day.ago)
      charge.update_columns(receipt_due_at: 10.days.from_now)

      charge.materialize_card_locking!(now:, trusted: false)

      expect(charge.receipt_due_at).to be_within(1.second).of(10.days.from_now)
    end

    it "does not set receipt_due_at for a charge settled before enforcement began" do
      pre_enforcement_settled_at = Time.zone.parse("2026-07-01")
      charge = create_settled_card_charge(user:, settled_at: pre_enforcement_settled_at)

      charge.materialize_card_locking!(now:, trusted: false)

      expect(charge.receipt_due_at).to be_nil
    end

    it "clears the deadline when the charge stops being receipt-required" do
      charge = create_settled_card_charge(user:, settled_at: 5.days.ago)
      charge.update!(receipt_due_at: 2.days.from_now)
      allow(charge).to receive(:receipt_required?).and_return(false)

      charge.materialize_card_locking!(now:, trusted: false)

      expect(charge.receipt_due_at).to be_nil
    end
  end

  describe "#restart_card_locking_countdown!" do
    it "restarts an overdue charge's countdown from now" do
      charge = create_settled_card_charge(user:, settled_at: 20.days.ago)
      charge.update_columns(receipt_due_at: 13.days.ago)

      charge.restart_card_locking_countdown!(now:)

      expect(charge.receipt_due_at).to be_within(1.second).of(now + 7.days)
    end

    it "gives a charge with no deadline yet a full 7 days rather than the first-deadline floor" do
      charge = create_settled_card_charge(user:, settled_at: 20.days.ago)
      charge.update_columns(receipt_due_at: nil)

      charge.restart_card_locking_countdown!(now:)

      expect(charge.receipt_due_at).to be_within(1.second).of(now + 7.days)
    end

    it "keeps a deadline that is already later than 7 days from now" do
      charge = create_settled_card_charge(user:, settled_at: 1.day.ago)
      charge.update_columns(receipt_due_at: 10.days.from_now)

      charge.restart_card_locking_countdown!(now:)

      expect(charge.receipt_due_at).to be_within(1.second).of(10.days.from_now)
    end

    it "sets no deadline for a charge settled before enforcement began" do
      charge = create_settled_card_charge(user:, settled_at: Time.zone.parse("2026-07-01"))

      charge.restart_card_locking_countdown!(now:)

      expect(charge.receipt_due_at).to be_nil
    end
  end
end
