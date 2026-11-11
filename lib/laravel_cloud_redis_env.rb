# frozen_string_literal: true

require "uri"

# Laravel Cloud injects the parts of an attached Valkey (Redis-compatible)
# cache as REDIS_HOST / REDIS_PORT / REDIS_USERNAME / REDIS_PASSWORD, but HCB
# reads full URLs from REDIS_URL (Sidekiq) and REDIS_CACHE_URL (cache store,
# Action Cable). Build those URLs from the parts when they aren't already set.
# Laravel Valkey only accepts TLS connections, so the scheme defaults to rediss.
module LaravelCloudRedisEnv
  def self.apply!(env = ENV)
    host = env["REDIS_HOST"].to_s
    return if host.empty?

    url = build_url(env, host)
    env["REDIS_URL"] = url if env["REDIS_URL"].to_s.empty?
    env["REDIS_CACHE_URL"] = url if env["REDIS_CACHE_URL"].to_s.empty?
  end

  def self.build_url(env, host)
    scheme = %w[tcp redis].include?(env["REDIS_SCHEME"].to_s.downcase) ? "redis" : "rediss"
    username = env["REDIS_USERNAME"].to_s
    password = env["REDIS_PASSWORD"].to_s
    port = env["REDIS_PORT"].to_s.empty? ? 6379 : env["REDIS_PORT"]

    userinfo = if password.empty?
                 nil
               else
                 "#{URI.encode_www_form_component(username)}:#{URI.encode_www_form_component(password)}"
               end

    URI::Generic.build(scheme:, userinfo:, host:, port: port.to_i).to_s
  end

end
