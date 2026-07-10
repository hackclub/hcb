# frozen_string_literal: true

require "rails_helper"

RSpec.describe UserService::RefreshReceiptDeadlines do
  include_context "card locking charges"

  let(:now) { Time.zone.parse("2026-10-10 12:00:00") }

  before { travel_to(now) }

  def materialize_all
    HcbCode.where(hcb_code: user.stripe_cards.flat_map { |c| c.local_hcb_codes.pluck(:hcb_code) })
           .find_each { |hc| hc.materialize_card_locking!(now:) }
  end

  it "sets settled_at and an untrusted 7-day due date on a fresh outstanding charge" do
    hcb_code = create_settled_card_charge(user:, settled_at: 1.day.ago)

    described_class.new(user:).run

    hcb_code.reload
    expect(hcb_code.receipt_settled_at).to be_within(2.seconds).of(1.day.ago)
    expect(hcb_code.receipt_due_at).to be_within(2.seconds).of(1.day.ago + 7.days)
  end

  it "slides due dates for a trusted cardholder to their most recent charge" do
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

  it "does not shorten an outstanding charge below 72h when trust is lost" do
    hcb_code = create_settled_card_charge(user:, settled_at: 6.days.ago)
    hcb_code.update_columns(receipt_settled_at: 6.days.ago, receipt_due_at: now + 5.days)

    allow_any_instance_of(User).to receive(:receipt_trusted?).and_return(false)
    allow_any_instance_of(User).to receive(:last_settled_charge_at).and_return(6.days.ago)

    described_class.new(user:).run

    hcb_code.reload
    expect(hcb_code.receipt_due_at).to be_within(2.seconds).of(now + 72.hours)
  end

  it "leaves an already-overdue charge frozen" do
    hcb_code = create_settled_card_charge(user:, settled_at: 10.days.ago)
    hcb_code.update_columns(receipt_settled_at: 10.days.ago, receipt_due_at: 2.days.ago)

    described_class.new(user:).run

    hcb_code.reload
    expect(hcb_code.receipt_due_at).to be_within(2.seconds).of(2.days.ago)
  end
end
