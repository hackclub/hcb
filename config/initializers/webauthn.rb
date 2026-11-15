# frozen_string_literal: true

WebAuthn.configure do |config|
  if Rails.env.local?
    config.allowed_origins = ["http://#{Credentials.fetch(:TEST_URL_HOST)}"]
  else
    config.allowed_origins = ["https://#{Credentials.fetch(:LIVE_URL_HOST)}"]
  end

  config.rp_name = "Hack Club Bank"
end
