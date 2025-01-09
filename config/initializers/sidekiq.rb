# frozen_string_literal: true

schedule_file = "config/schedule.yml"

Sidekiq.configure_server do |config|
  config.redis = { ssl_params: { verify_mode: OpenSSL::SSL::VERIFY_NONE } }

  config.capsule("throttled") do |capsule|
    capsule.queues = %w[wrapped]
    capsule.concurrency = 3
  end
end

Sidekiq.configure_client do |config|
  config.redis = { ssl_params: { verify_mode: OpenSSL::SSL::VERIFY_NONE } }
end

if File.exist?(schedule_file) && Sidekiq.server?
  Sidekiq::Cron::Job.load_from_hash YAML.load_file(schedule_file)
end

Sidekiq.strict_args!(:warn)
