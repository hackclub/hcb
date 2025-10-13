# frozen_string_literal: true

Rails.application.configure do
  # Verify Twilio webhooks
  config.middleware.use Rack::TwilioWebhookAuthentication, Credentials.fetch(:TWILIO, :AUTH_TOKEN), "/twilio/webhook"
end
