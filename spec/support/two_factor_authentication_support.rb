# frozen_string_literal: true

module TwoFactorAuthenticationSupport
  # Turns on an organization's two-factor authentication requirement as of
  # `at`. Specs run Flipper on the in-memory adapter, which keeps no
  # timestamps, so the persisted gate row the app reads the enable time from
  # is created by hand.
  def require_two_factor_authentication!(event, at: Time.current)
    Flipper.enable_actor(:require_two_factor_authentication_2026_11_24, event)
    Flipper::Adapters::ActiveRecord::Gate.create!(feature_key: "require_two_factor_authentication_2026_11_24", key: "actors", value: event.flipper_id, created_at: at, updated_at: at)
  end
end

RSpec.configure do |config|
  config.include TwoFactorAuthenticationSupport
end
