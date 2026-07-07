# frozen_string_literal: true

ActiveJob::TrafficControl.client = Redis.new(
  url: ENV["REDIS_URL"],
  ssl_params: { verify_mode: OpenSSL::SSL::VERIFY_NONE }
)
