# frozen_string_literal: true

schedule_file = "config/schedule.yml"

Sidekiq.configure_server do |config|
  # Metrics (HCB Wrapped) is given its own capsule since these jobs can be
  # long-running. Long running jobs can cause Sidekiq's usual queue-based
  # priority system to be ineffective.
  #
  # Imagine a scenario where you have 10 threads. You queue 15 long running jobs
  # as `low`, and then another 5 important jobs as `critical`.
  # All 10 sidekiq threads will pick up the first 10 `low` jobs first, and only
  # once they finish can it pick up the 5 `critical` jobs. After
  # finishing the `critical` jobs, it will then pick up the remaining 5 `low`
  # jobs. This means `critical` jobs can be blocked by long-running `low` jobs.
  #
  # Giving these long-running jobs its own capsule guarantees the other queues
  # (like `critical`) are not blocked by long-running jobs.
  config.capsule("throttled") do |capsule|
    capsule.queues = %w[metrics]
    capsule.concurrency = ENV.fetch("SIDEKIQ_THROTTLED_QUEUE_CONCURRENCY", 5).to_i
  end
end

# sidekiq-cron silently skips a scheduled run if it first checks the schedule
# more than `reschedule_grace_period` seconds after the run was due, and never
# catches it up. Its default of 60 seconds can be shorter than a Sidekiq
# restart, so a run that comes due while Sidekiq is restarting could be
# dropped. Only the most recent missed run is enqueued, so a longer outage
# doesn't cause a burst of catch-up jobs.
Sidekiq::Cron.configure do |config|
  config.reschedule_grace_period = 5.minutes.to_i
end

if File.exist?(schedule_file) && Sidekiq.server?
  Sidekiq::Cron::Job.load_from_hash YAML.load_file(schedule_file)
end

Sidekiq.strict_args!(:warn)
