# frozen_string_literal: true

stripe_environment = Rails.env.production? ? :live : :test

# update as needed, we specify explicitly in code to avoid inter-branch API version conflicts
Stripe.api_version = "2024-06-20"
Stripe.api_key = Credentials.fetch(:STRIPE, stripe_environment, :SECRET_KEY)
