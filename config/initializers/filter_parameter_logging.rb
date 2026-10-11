# frozen_string_literal: true

# Be sure to restart your server when you modify this file.

# Configure parameters to be partially matched (e.g. passw matches password) and filtered from the log file.
# Use this to limit dissemination of sensitive information.
# See the ActiveSupport::ParameterFilter documentation for supported notations and behaviors.
Rails.application.config.filter_parameters += [
  :passw, :email, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn, :cvv, :cvc,
  # Anchored: filter keys match as substrings, so a bare :tin would also redact
  # `routing_number` and `destination_*`, and a bare :ein would redact `being`.
  /\A(us_?)?f?tin\z/i, /\Aein\z/i
]
