# frozen_string_literal: true

WebAuthn.configure do |config|
  if Rails.env.staging?
    # Use the Heroku review app's origin
    heroku_app_name = ENV["HEROKU_APP_NAME"]
    config.allowed_origins = ["https://#{heroku_app_name}.herokuapp.com"]
  elsif Rails.env.production?
    config.allowed_origins = ["https://#{Credentials.fetch(:LIVE_URL_HOST)}"]
  else
    config.allowed_origins = ["http://#{Credentials.fetch(:TEST_URL_HOST)}"]
  end

  config.rp_name = "Hack Club Bank"
end
