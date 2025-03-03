# frozen_string_literal: true

# See https://github.com/hackclub/hcb/pull/8073.
# For production & GitHub actions, credentials are synced using https://docs.doppler.com/docs/github-actions and https://docs.doppler.com/docs/heroku.
# Locally, use a `DOPPLER_TOKEN` (https://docs.doppler.com/docs/service-tokens) to load in enviroment variables.
# A `DOPPLER_TOKEN` is also configured for every Heroku staging deploy at the moment.

module Credentials
  NESTING_DELIMITER = "__"

  def self.fetch(*key_segments)
    key = key_segments.join(NESTING_DELIMITER)
    ENV[key] || Rails.application.credentials[key]
  end

  module Doppler
    # adapted from https://github.com/DopplerHQ/ruby-doppler-env/tree/main.
    DOPPLER_TOKEN = ENV["DOPPLER_TOKEN"]
    DOPPLER_PROJECT = ENV["DOPPLER_PROJECT"]
    DOPPLER_CONFIG = ENV["DOPPLER_CONFIG"]
    DOPPLER_URL = URI("https://api.doppler.com/v3/configs/config/secrets/download")

    module_function

    # loads secrets into ENV so long as the variable doesn't already exist
    def load_secrets(secrets)
      secrets.each do |k, v|
        ENV[k] ||= v
      end
      puts "Secrets loaded successfully from Doppler:"
      puts "project=#{ENV["DOPPLER_PROJECT"]} config=#{ENV["DOPPLER_CONFIG"]} environment=#{ENV["DOPPLER_ENVIRONMENT"]}"
    end

    def fetch_secrets
      params = { project: DOPPLER_PROJECT, config: DOPPLER_CONFIG, format: "json" }
      DOPPLER_URL.query = URI.encode_www_form(params)

      req = Net::HTTP::Get.new(DOPPLER_URL)
      req.basic_auth DOPPLER_TOKEN, ""

      res = Net::HTTP.start(DOPPLER_URL.hostname, DOPPLER_URL.port, use_ssl: true) do |http|
        http.request(req)
      end

      case res
      when Net::HTTPSuccess
        return JSON.parse(res.body)
      when Net::HTTPUnauthorized
        puts "Unauthorized: No secrets loaded from Doppler. Please make sure you're using a valid Doppler token."
      else
        puts "Error: No secrets loaded from Doppler. A failure occurred while attempting to load secrets."
        puts res.inspect
      end
    end

    def load
      secrets = fetch_secrets
      if secrets
        load_secrets(secrets)
      end
    end
  end
end
