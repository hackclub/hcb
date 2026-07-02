# frozen_string_literal: true

# Compares the old balance engine (Event#balance_v2_cents, treated as ground
# truth) against the new Ledger engine (Ledger#balance_cents) across every
# organization, and caches the aggregate "money printer" stats for the public
# dashboard. Runs on a schedule because the full sweep is expensive.
class MoneyPrinterStatsJob < ApplicationJob
  queue_as :low

  CACHE_KEY = "money_printer:stats"
  ENQUEUED_KEY = "money_printer:stats:enqueued"
  # Safety net: if the cron stops running, the cache expires and the dashboard
  # falls back to the warming-up state rather than showing stale numbers
  # forever. Under normal operation the 15-minute cron rewrites it first.
  CACHE_TTL = 1.week
  LEADERBOARD_SIZE = 25

  def perform
    Rails.cache.write(CACHE_KEY, self.class.compute_stats, expires_in: CACHE_TTL)
  ensure
    Rails.cache.delete(ENQUEUED_KEY)
  end

  def self.compute_stats
    sum_old = 0
    sum_new = 0
    matching = 0
    total = 0
    discrepancies = []

    Event.includes(:ledger).find_each do |event|
      old_cents = event.balance_v2_cents
      new_cents = event.ledger&.balance_cents || 0
      delta = new_cents - old_cents

      sum_old += old_cents
      sum_new += new_cents
      total += 1
      matching += 1 if delta.zero?

      next if delta.zero?

      discrepancies << {
        event_id: event.id,
        public_id: event.public_id,
        slug: event.slug,
        name: event.name,
        delta_cents: delta
      }
    end

    leaderboard = discrepancies.sort_by { |e| -e[:delta_cents].abs }.first(LEADERBOARD_SIZE)

    {
      net_delta_cents: sum_new - sum_old,
      sum_old_cents: sum_old,
      sum_new_cents: sum_new,
      total_orgs: total,
      matching_orgs: matching,
      leaderboard:,
      computed_at: Time.current
    }
  end

end
