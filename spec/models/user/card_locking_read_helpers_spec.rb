# frozen_string_literal: true

require "rails_helper"

RSpec.describe User do
  include_context "card locking charges"

  let(:now) { Time.zone.parse("2026-10-10 12:00:00") }

  before { travel_to(now) }

  describe "#card_locking_suppressed?" do
    it "is true when card_locking_suppressed_until is in the future" do
      user.update!(card_locking_suppressed_until: 1.day.from_now)

      expect(user.card_locking_suppressed?(now:)).to eq(true)
    end

    it "is false when card_locking_suppressed_until is nil" do
      user.update!(card_locking_suppressed_until: nil)

      expect(user.card_locking_suppressed?(now:)).to eq(false)
    end

    it "is false when card_locking_suppressed_until is in the past" do
      user.update!(card_locking_suppressed_until: 1.day.ago)

      expect(user.card_locking_suppressed?(now:)).to eq(false)
    end
  end

  describe "#card_locking_overdue_charges" do
    it "includes a charge past its deadline with no resolution" do
      hc = create_settled_card_charge(user:, settled_at: 2.days.ago)
      hc.update!(receipt_due_at: 1.day.ago, receipt_resolved_at: nil)

      expect(user.card_locking_overdue_charges(now:)).to include(hc)
    end

    it "excludes a charge that is not yet due" do
      hc = create_settled_card_charge(user:, settled_at: 2.days.ago)
      hc.update!(receipt_due_at: 1.day.from_now, receipt_resolved_at: nil)

      expect(user.card_locking_overdue_charges(now:)).not_to include(hc)
    end

    it "excludes a resolved charge" do
      hc = create_settled_card_charge(user:, settled_at: 2.days.ago)
      hc.update!(receipt_due_at: 1.day.ago, receipt_resolved_at: 1.hour.ago)

      expect(user.card_locking_overdue_charges(now:)).not_to include(hc)
    end
  end

  describe "#card_locking_has_approaching_charge?" do
    it "is true when a charge is due within the warning lead time" do
      hc = create_settled_card_charge(user:, settled_at: 5.days.ago)
      hc.update!(receipt_due_at: 1.day.from_now, receipt_resolved_at: nil)

      expect(user.card_locking_has_approaching_charge?(now:)).to eq(true)
    end

    it "is true when a charge is already overdue" do
      hc = create_settled_card_charge(user:, settled_at: 8.days.ago)
      hc.update!(receipt_due_at: 1.day.ago, receipt_resolved_at: nil)

      expect(user.card_locking_has_approaching_charge?(now:)).to eq(true)
    end

    it "is false when the only outstanding charge is still fresh" do
      hc = create_settled_card_charge(user:, settled_at: 1.hour.ago)
      hc.update!(receipt_due_at: 6.days.from_now, receipt_resolved_at: nil)

      expect(user.card_locking_has_approaching_charge?(now:)).to eq(false)
    end
  end

  describe "#card_locking_outstanding_charges and #card_locking_outstanding_count" do
    it "counts an outstanding (no receipt) settled charge" do
      create_settled_card_charge(user:, settled_at: 1.hour.ago)

      expect(user.card_locking_outstanding_charges.count).to eq(1)
      expect(user.card_locking_outstanding_count).to eq(1)
    end

    it "excludes a resolved (receipt uploaded) charge" do
      create_settled_card_charge(user:, settled_at: 1.hour.ago, uploaded_at: Time.current)

      expect(user.card_locking_outstanding_charges.count).to eq(0)
      expect(user.card_locking_outstanding_count).to eq(0)
    end
  end

  describe "#card_locking_next_due_at" do
    it "is the soonest deadline in the outstanding pile" do
      soonest = create_settled_card_charge(user:, settled_at: 5.days.ago)
      soonest.update!(receipt_due_at: 11.hours.from_now)
      later = create_settled_card_charge(user:, settled_at: 1.day.ago)
      later.update!(receipt_due_at: 6.days.from_now)

      expect(user.card_locking_next_due_at).to eq(soonest.receipt_due_at)
    end

    it "ignores charges that already have a receipt" do
      resolved = create_settled_card_charge(user:, settled_at: 5.days.ago, uploaded_at: Time.current)
      resolved.update!(receipt_due_at: 11.hours.from_now)
      outstanding = create_settled_card_charge(user:, settled_at: 1.day.ago)
      outstanding.update!(receipt_due_at: 6.days.from_now)

      expect(user.card_locking_next_due_at).to eq(outstanding.receipt_due_at)
    end

    # A cardholder in no rollout stage has no deadlines at all; MIN over NULLs is
    # NULL, so there is nothing to count down to.
    it "is nil when the outstanding pile carries no deadlines" do
      hc = create_settled_card_charge(user:, settled_at: 1.day.ago)
      hc.update!(receipt_due_at: nil)

      expect(user.card_locking_next_due_at).to be_nil
    end

    it "is nil when nothing is outstanding" do
      expect(user.card_locking_next_due_at).to be_nil
    end
  end
end
