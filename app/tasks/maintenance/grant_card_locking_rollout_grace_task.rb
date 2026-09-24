# frozen_string_literal: true

module Maintenance
  # One-off, for the general rollout only. Pushes every already-overdue receipt
  # deadline out to now + GRACE, so switching enforcement on for everyone warns
  # cardholders before it locks them instead of locking them on the next sweep.
  #
  # It exists because the two rollout flags cover different populations. The stage
  # flag has been materializing deadlines for a whole group of cardholders, while
  # the kill switch (which gates locking AND every notification) was on for a much
  # smaller set. Cardholders in the gap have had deadlines quietly going
  # overdue for weeks without a single email or SMS, some of them across dozens of
  # charges. Opening the master gate would lock all of them at once, with the lock
  # notice as their first contact with the feature.
  #
  # Cardholders whose cards are already locked are skipped: they are already being
  # enforced and have had the notifications, so granting grace would unlock them,
  # mail them that their cards work again, and re-lock them GRACE later.
  #
  # Run this BEFORE enabling the kill switch globally. Idempotent in the
  # sense that a second run only re-grants grace to whoever is still overdue, but
  # it is meant to run once, immediately before the flag flip.
  class GrantCardLockingRolloutGraceTask < MaintenanceTasks::Task
    # Leaves a full WARNING_LEAD_TIME (48h) of warning before the lock lands, so
    # every affected cardholder gets an email and SMS roughly 24h out.
    GRACE = CardLocking::DEADLINE_SHORTENING_FLOOR

    def collection
      HcbCode.card_locking_candidates
             .receipt_overdue
             .where(stripe_cardholders: { user_id: User.where(cards_locked: false) })
             .distinct
    end

    def process(hcb_code)
      # The sweep will not claw this back: Deadline#compute's shortening branch
      # clamps to min(max(target, now + 72h), current_due_at), which holds at the
      # granted value rather than dropping to the original settled_at + 7 days.
      hcb_code.update_columns(receipt_due_at: GRACE.from_now)
    end

  end
end
