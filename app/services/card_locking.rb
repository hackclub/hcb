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

  # The Receipt Bin URL cardholders are sent to upload outstanding receipts.
  def self.inbox_url
    Rails.application.routes.url_helpers.my_inbox_url
  end
end
