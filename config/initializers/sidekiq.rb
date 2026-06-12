# frozen_string_literal: true

schedule_file = "config/schedule.yml"

Sidekiq.configure_server do |config|
  config.redis = { ssl_params: { verify_mode: OpenSSL::SSL::VERIFY_NONE } }

  # Metrics (HCB Wrapped) is given it's own capsule since these jobs can be
  # long-running. Long running jobs can cause Sidekiq's usual queue-based
  # priority system to be ineffective.
  #
  # Imagine a scenario where you have 10 threads. You queue 15 long running jobs
  # as `low`, and then another 5 important jobs as `critical`.
  # All 10 sidekiq threads will pick up the first 10 `low` jobs first, and only
  # once they finish can it pick up the 5 `critical` jobs. After after
  # finishing the `critical` jobs, it will then pick up the remaining 5 `low`
  # jobs. This means `critical` jobs can be blocked by long-running `low` jobs.
  #
  # Giving these long-running jobs it's own capsule guarantees the other queues
  # (like `critical`) are not blocked by long-running jobs.
  config.capsule("throttled") do |capsule|
    capsule.queues = %w[metrics]
    capsule.concurrency = ENV.fetch("SIDEKIQ_THROTTLED_QUEUE_CONCURRENCY", 5).to_i
  end
end

Sidekiq.configure_client do |config|
  config.redis = { ssl_params: { verify_mode: OpenSSL::SSL::VERIFY_NONE } }
end

if File.exist?(schedule_file) && Sidekiq.server?
  Sidekiq::Cron::Job.load_from_hash YAML.load_file(schedule_file)
end

Sidekiq.strict_args!(:warn)
