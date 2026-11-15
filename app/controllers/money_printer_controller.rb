# frozen_string_literal: true

class MoneyPrinterController < ApplicationController
  FLAG = :money_printer_2026_06_30

  skip_before_action :signed_in_user
  skip_before_action :redirect_to_onboarding
  skip_after_action :verify_authorized

  def index
    return head :not_found unless Flipper.enabled?(FLAG, current_user)

    @stats = Rails.cache.read(MoneyPrinterStatsJob::CACHE_KEY)
    @warming_up = @stats.nil?
    @reveal_identities = auditor_signed_in?

    if @warming_up
      enqueue_warmup
    else
      @mode = printer_mode(@stats[:net_delta_cents])
      @accuracy = accuracy_pct(@stats)
    end
  end

  private

  # Public, auto-refreshing page: guard against a job stampede by enqueuing at
  # most one warm-up at a time. The job clears the flag when it finishes; this
  # expiry is only a backstop if the job dies. The full sweep takes ~2 minutes,
  # so keep the backstop well above that but under the 15-minute cron interval.
  def enqueue_warmup
    lock_acquired = Rails.cache.write(
      MoneyPrinterStatsJob::ENQUEUED_KEY, true,
      unless_exist: true, expires_in: 10.minutes
    )
    MoneyPrinterStatsJob.perform_later if lock_acquired
  end

  def printer_mode(net_delta_cents)
    return "printing" if net_delta_cents.positive?
    return "shredding" if net_delta_cents.negative?

    "jammed"
  end

  def accuracy_pct(stats)
    return 100.0 if stats[:total_orgs].zero?

    stats[:matching_orgs].to_f / stats[:total_orgs] * 100
  end

end
