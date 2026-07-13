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
  ENFORCEMENT_START_DATE = Date.new(2026, 7, 14)

  # Staged rollout of enforcement. A cardholder's charges become lockable on the
  # date of the first stage flag they carry; a cardholder in no stage is never
  # enforced (their charges never get a deadline, so their cards never lock).
  #
  # RIP-OUT: when the rollout is done, delete ENFORCEMENT_STAGES and
  # enforcement_start_date, have callers use ENFORCEMENT_START_DATE directly, and
  # remove the Flipper flags. To add a stage, add a row (keep earliest first).
  ENFORCEMENT_STAGES = [
    [:card_locking_enabled_on_07_14_2026, Date.new(2026, 7, 14)],
    [:card_locking_enabled_on_07_28_2026, Date.new(2026, 7, 28)],
  ].freeze

  # The date on or after which this cardholder's charges can lock their cards, or
  # nil if they are not yet in any rollout stage.
  def self.enforcement_start_date(user)
    return nil unless user

    ENFORCEMENT_STAGES.each { |flag, date| return date if Flipper.enabled?(flag, user) }
    nil
  end

  # The Receipt Bin URL cardholders are sent to upload outstanding receipts.
  def self.inbox_url
    Rails.application.routes.url_helpers.my_inbox_url
  end
end
