# frozen_string_literal: true

module CardLocking
  # A receipt is due this long after its charge settles.
  RECEIPT_DUE_WINDOW = 7.days

  # No receipt may ever be outstanding longer than this, whatever the spending
  # pattern. Bounds the sliding deadline for a continuous spender.
  RECEIPT_MAX_AGE = 14.days

  # When a deadline recomputes earlier (e.g. trust was lost), it may not drop
  # below this much time from now. Prevents a pile going overdue in one instant.
  DEADLINE_SHORTENING_FLOOR = 72.hours

  # A cardholder is trusted at or above this on-time rate (with the recency clause).
  TRUST_ON_TIME_RATE = 0.80

  # Trust is computed over charges settled within this window.
  TRUST_LOOKBACK = 6.months

  # The pre-lock warning only fires when a charge is at least this close to its
  # deadline, so a cardholder whose charges all still have a full week of runway
  # is not nudged every day.
  WARNING_LEAD_TIME = 48.hours

  # Staged rollout of enforcement. A cardholder's charges become lockable on the
  # earliest stage date they hold a flag for; a cardholder in no stage is never
  # enforced. Earliest-wins is what leaves an already-enforced cardholder untouched
  # when a later stage is switched on for everyone.
  #
  # Adding a stage is just a new entry. Repointing one later, disabling one on an
  # enforced cardholder, or deleting the earliest entry all push that cardholder's
  # date forward, and the next sweep then wipes their deadlines, unlocks their
  # cards, and mails them that their cards work again.
  #
  # RIP-OUT: re-pin ENFORCEMENT_START_DATE to the literal Date.new(2026, 7, 17)
  # first, then delete this hash and enforcement_start_date, have callers use
  # ENFORCEMENT_START_DATE directly, and remove the Flipper flags.
  ENFORCEMENT_STAGES = {
    card_locking_enabled_on_07_17_2026: Date.new(2026, 7, 17),
    card_locking_enabled_on_08_11_2026: Date.new(2026, 8, 11),
  }.freeze

  # Charges settled before this can never lock a card, whatever stage a cardholder
  # is in; it bounds candidate discovery and the outstanding pile. Derived from the
  # earliest stage so a later one can never push it forward, which would drop
  # earlier-stage charges out of card_locking_candidates and unlock cardholders
  # already being enforced.
  ENFORCEMENT_START_DATE = ENFORCEMENT_STAGES.values.min

  # The date on or after which this cardholder's charges can lock their cards, or
  # nil if they are not yet in any rollout stage.
  def self.enforcement_start_date(user)
    return nil unless user

    ENFORCEMENT_STAGES.filter_map { |flag, date| date if Flipper.enabled?(flag, user) }.min
  end

  # The Receipt Bin URL cardholders are sent to upload outstanding receipts.
  def self.inbox_url
    Rails.application.routes.url_helpers.my_inbox_url
  end
end
