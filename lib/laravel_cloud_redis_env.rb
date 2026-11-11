# frozen_string_literal: true

require "uri"

# HCB reads Redis from two variables: REDIS_URL (Sidekiq) and REDIS_CACHE_URL
# (cache store, Action Cable). Laravel Cloud injects an attached Valkey cache
# as REDIS_URL only (rediss://, TLS), so without this the cache store and
# Action Cable fall back to localhost.
#
# Point REDIS_CACHE_URL at REDIS_URL when it isn't set. If only the individual
# parts are present (REDIS_HOST / REDIS_PORT / REDIS_USERNAME / REDIS_PASSWORD),
# build REDIS_URL from them first. Setups that already set both URLs are
# untouched.
module LaravelCloudRedisEnv
  def self.apply!(env = ENV)
    env["REDIS_URL"] = build_url(env) if blank?(env["REDIS_URL"]) && !blank?(env["REDIS_HOST"])
    return if blank?(env["REDIS_URL"])

    env["REDIS_CACHE_URL"] = env["REDIS_URL"] if blank?(env["REDIS_CACHE_URL"])
  end

  def self.build_url(env)
    scheme = %w[tcp redis].include?(env["REDIS_SCHEME"].to_s.downcase) ? "redis" : "rediss"
    password = env["REDIS_PASSWORD"].to_s
    port = blank?(env["REDIS_PORT"]) ? 6379 : env["REDIS_PORT"].to_i

    userinfo = if password.empty?
                 nil
               else
                 "#{URI.encode_www_form_component(env["REDIS_USERNAME"].to_s)}:#{URI.encode_www_form_component(password)}"
               end

    URI::Generic.build(scheme:, userinfo:, host: env["REDIS_HOST"], port:).to_s
  end

  def self.blank?(value)
    value.to_s.strip.empty?
  end

end
