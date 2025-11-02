# frozen_string_literal: true

Rails.application.configure do
  unless Rails.env.local?
    # StatsD config here
    ENV["STATSD_ENV"] = "production" # This won't send data unless set to production
    ENV["STATSD_ADDR"] = "telemetry.hackclub.com:8125"
  end

  ENV["STATSD_PREFIX"] = "#{Rails.env}.hcb"

  StatsD::Instrument::Environment.setup

  StatsD.increment("startup", 1)
end
