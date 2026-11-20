# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Card locking, end to end", type: :model do
  include ActiveJob::TestHelper
  include_context "card locking charges"

  before do
    Flipper.enable(:card_locking)
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
      expect(charge.reload).not_to be_missing_receipt
      expect(user.reload.cards_locked?).to be(false) # card came back
    end
  end

  # Deadlines are materialized onto ledger items from scratch (nothing is copied
  # from HCB codes), so the first sweep after the move sees charges with no
  # deadline at all. It must not read that as "nothing overdue" and release
  # every locked cardholder with a "your cards work again".
  describe "the sweep that first materializes deadlines" do
    it "keeps a locked cardholder locked, without any notification" do
      travel_to Time.zone.parse("2026-10-10 09:00:00") do
        charge = create_settled_card_charge(user:, settled_at: 10.days.ago)
        user.update!(cards_locked: true)
        expect(charge.receipt_due_at).to be_nil

        # No mail, no SMS, nothing: the mailers and the SMS are all jobs.
        expect { User::UpdateCardLocking::RecurringJob.perform_now }.not_to have_enqueued_job

        expect(user.reload.cards_locked?).to be(true)
        expect(charge.reload.receipt_due_at).to be_within(1.second).of(10.days.ago + 7.days)
      end
    end

    it "gives an unlocked cardholder's old charge the 72-hour floor rather than locking on the spot" do
      travel_to Time.zone.parse("2026-10-10 09:00:00") do
        charge = create_settled_card_charge(user:, settled_at: 10.days.ago)

        expect { User::UpdateCardLocking::RecurringJob.perform_now }.not_to have_enqueued_job

        expect(user.reload.cards_locked?).to be(false)
        expect(charge.reload.receipt_due_at).to be_within(1.second).of(72.hours.from_now)
      end
    end
  end
end
