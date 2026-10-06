# frozen_string_literal: true

Rails.application.configure do
  unless Rails.env.local?
    # StatsD config here
    ENV["STATSD_ENV"] = "production" # This won't send data unless set to production
    ENV["STATSD_ADDR"] = "telemetry.hackclub.com:8125"
  end

  ENV["STATSD_PREFIX"] = "#{Rails.env}.hcb"

  StatsD::Instrument::Environment.setup

  begin
    StatsD.increment("startup", 1)
  rescue Socket::ResolutionError, SocketError => e
    # Telemetry must never prevent the app from booting or serving requests
    # (StatsD is called inline in Stripe webhooks). Fall back to a no-op client.
    Rails.error.report(e, handled: true)
    StatsD.singleton_client = StatsD::Instrument::Client.new(sink: StatsD::Instrument::NullSink.new)
  end
end
