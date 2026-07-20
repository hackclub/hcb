# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Card locking, end to end", type: :model do
  include ActiveJob::TestHelper
  include_context "card locking charges"

  before do
    Flipper.enable(:card_locking_2025_06_09, user)
    # The stage flag (enforcement start 2026-07-14) comes from the shared context.
  end

  it "settles, sweeps a deadline, does not lock before it, locks after it via the cron, then unlocks on upload" do
    charge = nil

    # 1. A real charge settles with no receipt; the sweep sets settled_at + a 7-day
    #    (untrusted) deadline.
    travel_to Time.zone.parse("2026-10-01 09:00:00") do
      charge = create_settled_card_charge(user:, settled_at: Time.current)
      UserService::RefreshReceiptDeadlines.new(user:).run
      charge.reload
      expect(charge.card_charge_settled_at).to be_within(1.second).of(Time.current)
      expect(charge.receipt_due_at).to be_within(1.second).of(Time.current + 7.days)
    end

    # 2. Before the deadline, the recurring job must NOT lock.
    travel_to Time.zone.parse("2026-10-05 09:00:00") do
      User::UpdateCardLocking::RecurringJob.perform_now
      expect(user.reload.cards_locked?).to be(false)
    end

    # 3. After the deadline (due 2026-10-08), the recurring job locks (real overdue
    #    query + real service).
    travel_to Time.zone.parse("2026-10-09 09:00:00") do
      User::UpdateCardLocking::RecurringJob.perform_now
      expect(user.reload.cards_locked?).to be(true)
    end

    # 4. The cardholder uploads; the unlock fires on the upload path, not the cron.
    travel_to Time.zone.parse("2026-10-09 10:00:00") do
      perform_enqueued_jobs(only: User::UpdateCardLockingJob) do
        attach_receipt(charge, uploaded_by: user)
      end
      expect(charge.reload.receipt_resolved_at).to be_present # frozen on upload
      expect(user.reload.cards_locked?).to be(false)          # card came back
    end
  end
end
