# frozen_string_literal: true

require "rails_helper"

RSpec.describe Maintenance::GrantCardLockingRolloutGraceTask, type: :model do
  include_context "card locking charges"

  let(:now) { Time.zone.parse("2026-10-10 12:00:00") }

  before { travel_to(now) }

  def run_task
    task = described_class.new
    task.collection.each { |hcb_code| task.process(hcb_code) }
  end

  def overdue_charge(settled_at: 20.days.ago)
    create_settled_card_charge(user:, settled_at:).tap do |charge|
      charge.update_columns(card_charge_settled_at: settled_at, receipt_due_at: settled_at + 7.days)
    end
  end

  it "pushes an overdue deadline out to the grace window" do
    charge = overdue_charge

    run_task

    expect(charge.reload.receipt_due_at).to be_within(1.second).of(now + described_class::GRACE)
    expect(user.cards_should_lock?(now:)).to be(false)
  end

  it "leaves the grace outside the warning window, so the cardholder is warned before locking" do
    overdue_charge

    run_task

    expect(user.card_locking_has_approaching_charge?(now:)).to be(false)
    expect(user.card_locking_has_approaching_charge?(now: now + 25.hours)).to be(true)
    expect(user.cards_should_lock?(now: now + described_class::GRACE + 1.minute)).to be(true)
  end

  # An already-locked cardholder has had the notifications and is being enforced.
  # Granting grace would unlock them, mail them that their cards work again, and
  # re-lock them three days later.
  it "skips a cardholder whose cards are already locked" do
    charge = overdue_charge
    user.update!(cards_locked: true)

    run_task

    expect(charge.reload.receipt_due_at).to be_within(1.second).of(charge.card_charge_settled_at + 7.days)
  end

  it "leaves a charge that is not yet overdue alone" do
    settled_at = 1.day.ago
    charge = create_settled_card_charge(user:, settled_at:)
    charge.update_columns(card_charge_settled_at: settled_at, receipt_due_at: settled_at + 7.days)

    run_task

    expect(charge.reload.receipt_due_at).to be_within(1.second).of(settled_at + 7.days)
  end

  # The whole point of the grace is that it survives contact with the sweep.
  it "is not clawed back by the next deadline refresh" do
    charge = overdue_charge

    run_task
    UserService::RefreshReceiptDeadlines.new(user:, now:).run

    expect(charge.reload.receipt_due_at).to be_within(1.second).of(now + described_class::GRACE)
  end
end
