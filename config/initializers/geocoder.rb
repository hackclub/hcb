# frozen_string_literal: true

Geocoder.configure(
  timeout: 15,

  ip_lookup: :ipinfo_io,
  ipinfo_io: {
    api_key: Rails.application.credentials.ipinfo_io[:api_key],
  },

  cache: Redis.new(url: Rails.env.production? ? ENV["REDIS_CACHE_URL"] : ENV["REDIS_URL"], ssl_params: { verify_mode: OpenSSL::SSL::VERIFY_NONE }),
  cache_options: {
    # ipinfo.io rate limits at 50,000/month with a free account (about 70
    # requests per hour)
    expiration: 2.days,
  }
)
