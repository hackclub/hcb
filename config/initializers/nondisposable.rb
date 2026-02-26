# frozen_string_literal: true

Nondisposable.configure do |config|
  # Customize the error message if needed
  config.error_message = "provider is unsupported. Please try with another email address."

  # Add custom domains you want to be considered as disposable
  config.additional_domains = ["aboodbab.com"]

  # Exclude domains that are considered disposable but you want to allow anyways
  # config.excluded_domains = ["false-positive-domain.com"]
end
