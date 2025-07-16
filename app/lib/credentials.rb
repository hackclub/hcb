# frozen_string_literal: true

# See https://github.com/hackclub/hcb/pull/8073.
# For production & GitHub actions, credentials are synced using https://docs.doppler.com/docs/github-actions and https://docs.doppler.com/docs/heroku.
# Locally, use a `DOPPLER_TOKEN` (https://docs.doppler.com/docs/service-tokens) to load in environment variables.
# A `DOPPLER_TOKEN` is also configured for every Heroku staging deploy at the moment.

module Credentials
  NESTING_DELIMITER = "__"

  def self.fetch(*key_segments, fallback: nil)
    key = key_segments.join(NESTING_DELIMITER).upcase
    ENV[key] || Rails.application.credentials.dig(*key_segments) || fallback
  end

  def self.load
    secrets = Doppler.fetch_secrets
    return unless secrets

    # Load the secrets into ENV
    results = load_secrets(secrets)

    # Report on which secretes were loaded and which were skipped
    loaded, skipped = results.partition { |_k, v| v }.map(&:to_h).map(&:keys)
    puts "Loaded: #{loaded.inspect}"
    puts "Skipped: #{skipped.inspect}"
  end

  # loads secrets into ENV so long as the variable doesn't already exist
  private_class_method def self.load_secrets(secrets)
    secrets.to_h do |k, v|
      should_load = !ENV.key?(k)
      ENV[k] = v if should_load

      # Returns a hash of whether each key was loaded into ENV (or not).
      # NOTE: Running this method as second time should result in all values
      # being false since it was previously loaded.
      [k, should_load]
    end
  end

  module Doppler
    # adapted from https://github.com/DopplerHQ/ruby-doppler-env/tree/main.
    DOPPLER_TOKEN = ENV["DOPPLER_TOKEN"]
    DOPPLER_PROJECT = ENV["DOPPLER_PROJECT"]
    DOPPLER_CONFIG = ENV["DOPPLER_CONFIG"]
    DOPPLER_URL = URI("https://api.doppler.com/v3/configs/config/secrets/download")

    def self.fetch_secrets
      params = { project: DOPPLER_PROJECT, config: DOPPLER_CONFIG, format: "json" }
      DOPPLER_URL.query = URI.encode_www_form(params)

      req = Net::HTTP::Get.new(DOPPLER_URL)
      req.basic_auth DOPPLER_TOKEN, ""

      res = Net::HTTP.start(DOPPLER_URL.hostname, DOPPLER_URL.port, use_ssl: true) do |http|
        http.request(req)
      end

      case res
      when Net::HTTPSuccess
        puts "Successfully fetched secrets from Doppler: project=#{DOPPLER_PROJECT.inspect} config=#{DOPPLER_CONFIG.inspect}"

        return JSON.parse(res.body)
      when Net::HTTPUnauthorized
        puts "Unauthorized: No secrets loaded from Doppler. Please make sure you're using a valid Doppler token."
      else
        puts "Error: No secrets loaded from Doppler. A failure occurred while attempting to load secrets."
        puts res.inspect
      end
    end
  end
end
