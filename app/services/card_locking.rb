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

  # Charges that settled before this date can never lock a card, whatever stage a
  # cardholder is in. Bounds candidate discovery and the outstanding pile, and is
  # the single enforcement date the feature collapses to once the staged rollout
  # below finishes (see enforcement_start_date).
  #
  # It is a floor across *all* stages, so it must never be advanced to a later
  # stage's date. Doing so drops every earlier-stage charge out of
  # HcbCode.card_locking_candidates, which the lock decision, the sweep and the
  # outstanding pile all read through: the next sweep unlocks cardholders who are
  # already being enforced and mails them that their cards work again.
  ENFORCEMENT_START_DATE = Date.new(2026, 7, 17)

  # The feature kill switch, and the only Flipper flag card locking should end up
  # with. Global rather than per-actor: per-cardholder exemption is a separate
  # concern already served by users.card_locking_suppressed_until, which is
  # auditable and time-boxed where a flag actor is neither.
  #
  # Disabling it stops new locks AND releases existing ones (see
  # UserService::UpdateCardLocking). It deliberately does not gate deadline
  # materialization: deadlines keep being maintained while the feature is off,
  # which is harmless because nothing reads them for a lock decision, and clearing
  # them would lose the state the feature resumes from.
  def self.enabled?
    Flipper.enabled?(:card_locking)
  end

  # Staged rollout of enforcement. A cardholder's charges become lockable on the
  # earliest stage date they hold a flag for; a cardholder in no stage is never
  # enforced (their charges never get a deadline, so their cards never lock).
  #
  # Earliest-wins is what leaves an already-enforced cardholder untouched when a
  # later stage is switched on for everyone: they end up holding both flags and
  # keep their original date, so their deadlines and locks do not move. For the
  # same reason, never repoint an existing stage at a later date, never disable a
  # stage on an enforced cardholder, and never delete the earliest entry.
  #
  # RIP-OUT: when the rollout is done, delete ENFORCEMENT_STAGES and
  # enforcement_start_date, have callers use ENFORCEMENT_START_DATE directly, and
  # remove the Flipper flags. To add a stage, add an entry (order does not matter).
  ENFORCEMENT_STAGES = {
    card_locking_enabled_on_07_17_2026: Date.new(2026, 7, 17),
    card_locking_enabled_on_08_11_2026: Date.new(2026, 8, 11),
  }.freeze

  # The date on or after which this cardholder's charges can lock their cards, or
  # nil if they are not yet in any rollout stage.
  def self.enforcement_start_date(user)
    return nil unless user

    ENFORCEMENT_STAGES.filter_map { |flag, date| date if Flipper.enabled?(flag, user) }.min
  end

  # A deadline as it appears in cardholder-facing copy, in the cardholder's own
  # timezone (see User#time_zone, inferred from their last session). The zone
  # abbreviation is kept because the inference can be wrong, and a labelled time
  # someone can sanity-check beats a bare one they cannot.
  def self.format_deadline(time, zone)
    time.in_time_zone(zone).strftime("%b %-d at %-l:%M %p %Z")
  end

  # The Receipt Bin URL cardholders are sent to upload outstanding receipts.
  def self.inbox_url
    Rails.application.routes.url_helpers.my_inbox_url
  end

  # A deadline countdown for cardholder-facing copy: "45 minutes", "11 hours",
  # "3 days". Always rounds DOWN, so a cardholder is never told they have more
  # runway than they really do. Returns nil when there is no deadline or it has
  # already passed; callers say something other than a countdown in that case.
  #
  # Switches from hours to days at 48h (WARNING_LEAD_TIME) so the pre-lock
  # warning, which only fires inside that window, always counts down in hours.
  def self.time_remaining_in_words(due_at, now: Time.current)
    return nil if due_at.blank?

    seconds = (due_at - now).to_i
    return nil if seconds <= 0

    if seconds < 1.hour.to_i
      # Never round down to "0 minutes"; a deadline this close is still ahead.
      minutes = [seconds / 1.minute.to_i, 1].max
      "#{minutes} #{'minute'.pluralize(minutes)}"
    elsif seconds < WARNING_LEAD_TIME.to_i
      hours = seconds / 1.hour.to_i
      "#{hours} #{'hour'.pluralize(hours)}"
    else
      days = seconds / 1.day.to_i
      "#{days} #{'day'.pluralize(days)}"
    end
  end
end
