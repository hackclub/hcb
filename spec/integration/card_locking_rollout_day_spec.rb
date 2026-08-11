# frozen_string_literal: true

require "rails_helper"

# Covers what the global enforcement floor does, not just its value: it bounds
# candidate discovery, which the lock decision, the sweep and the outstanding pile
# all read through, so advancing it retroactively unlocks enforced cardholders.
# Charges settle in the 2026-07-17..08-10 window on purpose; the rest of the suite
# runs in October at relative offsets and so cannot see a floor move.
RSpec.describe "Card locking across the general rollout", type: :model do
  include_context "card locking charges"

  let(:now) { Time.zone.parse("2026-08-13 12:00:00") }
  let(:july_settled_at) { Time.zone.parse("2026-07-20 12:00:00") }

  before { travel_to(now) }

  # A pilot cardholder, holding the 08_11 flag too as they will once the general
  # stage is on for everyone. The master flag is required or UpdateCardLocking
  # returns early and the lock examples pass vacuously.
  before do
    Flipper.enable(:card_locking_2025_06_09, user)
    Flipper.enable(:card_locking_enabled_on_07_17_2026, user)
  end

  it "still locks a pilot cardholder on a July charge after the general rollout" do
    charge = create_settled_card_charge(user:, settled_at: july_settled_at)

    UserService::RefreshReceiptDeadlines.new(user:, now:).run

    expect(charge.reload.receipt_due_at).to be_within(1.second).of(july_settled_at + 7.days)
    expect(user.card_locking_overdue_charges(now:)).to include(charge)
    expect(user.cards_should_lock?(now:)).to be(true)
    expect(user.card_locking_outstanding_count).to eq(1)
  end

  it "leaves an already-locked pilot cardholder locked when the sweep re-runs" do
    create_settled_card_charge(user:, settled_at: july_settled_at)
      .update_columns(card_charge_settled_at: july_settled_at, receipt_due_at: july_settled_at + 7.days)
    user.update!(cards_locked: true)

    UserService::RefreshReceiptDeadlines.new(user:, now:).run
    UserService::UpdateCardLocking.new(user:).run

    expect(user.reload.cards_locked?).to be(true)
  end

  it "keeps refreshing the deadline of a July charge that still counts against the cardholder" do
    charge = create_settled_card_charge(user:, settled_at: july_settled_at)
    charge.update_columns(card_charge_settled_at: july_settled_at, receipt_due_at: july_settled_at + 30.days)

    UserService::RefreshReceiptDeadlines.new(user:, now:).run

    # Untrusted, so the stale far-future deadline is pulled back in, clamped by
    # the shortening floor rather than dropping straight to settled + 7 days.
    expect(charge.reload.receipt_due_at).to be_within(1.second).of(now + CardLocking::DEADLINE_SHORTENING_FLOOR)
  end

  it "does not lock a cardholder enrolled only in the general stage on their July charge" do
    Flipper.disable(:card_locking_enabled_on_07_17_2026, user)
    charge = create_settled_card_charge(user:, settled_at: july_settled_at)

    UserService::RefreshReceiptDeadlines.new(user:, now:).run

    expect(charge.reload.receipt_due_at).to be_nil
    expect(user.cards_should_lock?(now:)).to be(false)
    expect(user.card_locking_outstanding_count).to eq(0)
  end
end
