# frozen_string_literal: true

require "rails_helper"

RSpec.describe UserService::RefreshReceiptDeadlines do
  include_context "card locking charges"

  let(:now) { Time.zone.parse("2026-10-10 12:00:00") }

  before { travel_to(now) }

  it "sets settled_at and an untrusted 7-day due date on a fresh outstanding charge" do
    charge = create_settled_card_charge(user:, settled_at: 1.day.ago)

    described_class.new(user:).run

    charge.reload
    expect(charge.receipt_due_at).to be_within(2.seconds).of(1.day.ago + 7.days)
  end

  # Un-skip when grace periods are announced.
  it "slides due dates for a trusted cardholder to their most recent charge", :card_locking_trust, skip: "Trust is disabled" do
    # Deterministic on-time history: five charges settled 40-44 days ago, each with
    # a receipt uploaded the next day (well inside the 7-day window). They resolve on
    # time, giving a 100% on-time rate, so the cardholder is genuinely trusted.
    5.times do |i|
      offset = 40 + i
      create_settled_card_charge(user:, settled_at: offset.days.ago, uploaded_at: (offset - 1).days.ago)
    end
    old_outstanding = create_settled_card_charge(user:, settled_at: 4.days.ago)
    create_settled_card_charge(user:, settled_at: 1.day.ago)

    # First run materializes the outstanding charges so their settled_at is persisted
    # and counts toward last_settled_charge_at on the next run's slide.
    described_class.new(user:).run

    expect(user.reload.receipt_trusted?(now:)).to be(true)

    described_class.new(user:).run

    old_outstanding.reload
    expect(old_outstanding.receipt_due_at).to be_within(2.seconds).of(1.day.ago + 7.days)
  end

  it "does not shorten an outstanding charge below 72h when trust is lost", :card_locking_trust, skip: "Trust is disabled" do
    charge = create_settled_card_charge(user:, settled_at: 6.days.ago)
    charge.update_columns(receipt_due_at: now + 5.days)

    allow_any_instance_of(User).to receive(:receipt_trusted?).and_return(false)
    allow_any_instance_of(User).to receive(:last_settled_charge_at).and_return(6.days.ago)

    described_class.new(user:).run

    charge.reload
    expect(charge.receipt_due_at).to be_within(2.seconds).of(now + 72.hours)
  end

  it "leaves an already-overdue charge frozen" do
    charge = create_settled_card_charge(user:, settled_at: 10.days.ago)
    charge.update_columns(receipt_due_at: 2.days.ago)

    described_class.new(user:).run

    charge.reload
    expect(charge.receipt_due_at).to be_within(2.seconds).of(2.days.ago)
  end
end
