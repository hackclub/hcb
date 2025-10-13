# frozen_string_literal: true

stripe_environment = Rails.env.production? ? :live : :test

# update as needed, we specify explicitly in code to avoid inter-branch API version conflicts
Stripe.api_version = "2024-06-20"

api_key = Credentials.fetch(:STRIPE, stripe_environment, :SECRET_KEY)

if api_key.blank? && Rails.env.test?
  api_key = "sk_fake_#{SecureRandom.alphanumeric(32)}"
  warn("⚠️ Using fake Stripe API key: #{api_key.inspect}")
end

Stripe.api_key = api_key
