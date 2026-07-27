# frozen_string_literal: true

require "rails_helper"

RSpec.describe HcbCode do
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
      hcb_code = create_settled_card_charge(user:, settled_at: 5.days.ago, uploaded_at: 2.days.ago)

      expect(hcb_code.card_locking_resolved_at).to be_within(1.second).of(2.days.ago)
      expect(hcb_code).to be_card_locking_resolved
    end

    it "is marked_no_or_lost_receipt_at when the charge was marked without a receipt" do
      hcb_code = create_settled_card_charge(user:, settled_at: 5.days.ago)
      hcb_code.update!(marked_no_or_lost_receipt_at: 1.day.ago)

      expect(hcb_code.card_locking_resolved_at).to be_within(1.second).of(1.day.ago)
    end

    it "is nil for an unresolved charge" do
      hcb_code = create_settled_card_charge(user:, settled_at: 5.days.ago)

      expect(hcb_code.card_locking_resolved_at).to be_nil
      expect(hcb_code).not_to be_card_locking_resolved
    end
  end

  describe "#materialize_card_locking!" do
    it "sets card_charge_settled_at and receipt_due_at on a fresh untrusted charge" do
      hcb_code = create_settled_card_charge(user:, settled_at: 1.day.ago)

      hcb_code.materialize_card_locking!(now:, trusted: false)

      expect(hcb_code.card_charge_settled_at).to be_within(1.second).of(1.day.ago)
      expect(hcb_code.receipt_due_at).to be_within(1.second).of(1.day.ago + 7.days)
      expect(hcb_code.receipt_resolved_at).to be_nil
    end

    it "sets no deadline for a cardholder in no rollout stage" do
      Flipper.disable(:card_locking_enabled_on_07_17_2026, user)
      hcb_code = create_settled_card_charge(user:, settled_at: 1.day.ago)

      hcb_code.materialize_card_locking!(now:, trusted: false)

      expect(hcb_code.card_charge_settled_at).to be_within(1.second).of(1.day.ago)
      expect(hcb_code.receipt_due_at).to be_nil
    end

    it "sets no deadline for a charge that settled before the cardholder's stage date" do
      hcb_code = create_settled_card_charge(user:, settled_at: 1.day.ago)

      # A stage that starts after this charge settled: no deadline, can't lock.
      hcb_code.materialize_card_locking!(now:, trusted: false, enforcement_start_date: (now + 1.day).to_date)

      expect(hcb_code.receipt_due_at).to be_nil
    end

    it "slides receipt_due_at off the last settled charge when the cardholder is trusted" do
      hcb_code = create_settled_card_charge(user:, settled_at: 3.days.ago)

      hcb_code.materialize_card_locking!(now:, trusted: true, last_settled_charge_at: now - 1.hour)

      expect(hcb_code.receipt_due_at).to be_within(1.second).of((now - 1.hour) + 7.days)
    end

    it "freezes receipt_resolved_at at the time it was first materialized" do
      hcb_code = create_settled_card_charge(user:, settled_at: 5.days.ago, uploaded_at: 2.days.ago)

      hcb_code.materialize_card_locking!(now:, trusted: false)

      expect(hcb_code.receipt_resolved_at).to be_within(1.second).of(2.days.ago)
    end

    it "does not move card_charge_settled_at or receipt_resolved_at on repeated calls" do
      hcb_code = create_settled_card_charge(user:, settled_at: 5.days.ago, uploaded_at: 2.days.ago)
      hcb_code.materialize_card_locking!(now:, trusted: false)

      settled_at = hcb_code.card_charge_settled_at
      resolved_at = hcb_code.receipt_resolved_at

      hcb_code.materialize_card_locking!(now:, trusted: true, last_settled_charge_at: now - 1.hour)

      expect(hcb_code.card_charge_settled_at).to eq(settled_at)
      expect(hcb_code.receipt_resolved_at).to eq(resolved_at)
    end

    it "does not set receipt_due_at for a charge settled before enforcement began" do
      pre_enforcement_settled_at = Time.zone.parse("2026-07-01")
      hcb_code = create_settled_card_charge(user:, settled_at: pre_enforcement_settled_at)

      hcb_code.materialize_card_locking!(now:, trusted: false)

      expect(hcb_code.card_charge_settled_at).to be_within(1.second).of(pre_enforcement_settled_at)
      expect(hcb_code.receipt_due_at).to be_nil
    end

    it "clears all three columns when the charge stops being receipt-required" do
      hcb_code = create_settled_card_charge(user:, settled_at: 5.days.ago)
      hcb_code.update!(card_charge_settled_at: 5.days.ago, receipt_due_at: 2.days.from_now, receipt_resolved_at: 1.day.ago)
      allow(hcb_code).to receive(:receipt_required?).and_return(false)

      hcb_code.materialize_card_locking!(now:, trusted: false)

      expect(hcb_code.card_charge_settled_at).to be_nil
      expect(hcb_code.receipt_due_at).to be_nil
      expect(hcb_code.receipt_resolved_at).to be_nil
    end
  end
end
