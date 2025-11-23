# frozen_string_literal: true

WebAuthn.configure do |config|
  if Rails.env.production?
    config.origin = "https://#{Credentials.fetch(:LIVE_URL_HOST)}"

    config.allowed_origins = %w[https://hcb.hackclub.com https://ui3.hcb.hackclub.com]
    config.rp_id = "https://hcb.hackclub.com"
  else
    config.origin = "http://#{Credentials.fetch(:TEST_URL_HOST)}"
  end

  config.rp_name = "Hack Club Bank"
end
