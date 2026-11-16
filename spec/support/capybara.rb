# frozen_string_literal: true

require "capybara/cuprite"

# Capybara pings its local app server before each session
WebMock.disable_net_connect!(allow_localhost: true)

# Skip config/puma.rb, which fetches Doppler secrets when DOPPLER_TOKEN is set
Capybara.server = :puma, { Silent: true, config_files: ["-"] }

LOCAL_URL = /\Ahttp:\/\/127\.0\.0\.1:\d+\//
# <emoji-picker> downloads its emoji list from jsdelivr; ASCII since Ferrum sends character count as content-length
EMOJI_DATA = [{ annotation: "smile", emoji: ":)", group: 0, order: 1, version: 1 }].to_json
# The login code pages read device details for the session through these two (see fingerprint.js)
UA_PARSER_JS = "window.UAParser = function () { return { getResult: () => ({ browser: { name: 'Chrome', version: '1' }, os: { name: 'Linux', version: '' } }) } }"
FINGERPRINTJS_JS = "export const load = async () => ({ get: async () => ({ visitorId: 'test', components: { timezone: { value: 'UTC' } } }) })"
CDN_STUBS = {
  /\Ahttps:\/\/cdn\.jsdelivr\.net\/npm\/emoji-picker-element-data@/     => [EMOJI_DATA, "application/json"],
  /\Ahttps:\/\/cdn\.jsdelivr\.net\/npm\/ua-parser-js\//                 => [UA_PARSER_JS, "text/javascript"],
  /\Ahttps:\/\/cdn\.jsdelivr\.net\/npm\/@fingerprintjs\/fingerprintjs@/ => [FINGERPRINTJS_JS, "text/javascript"],
}.freeze

RSpec.configure do |config|
  # Match production so pages render the CSRF meta tags that fetch() calls read
  config.around(:each, type: :system) do |example|
    ActionController::Base.allow_forgery_protection = true
    example.run
  ensure
    ActionController::Base.allow_forgery_protection = false
  end

  config.before(:each, type: :system) do
    driven_by :cuprite, screen_size: [1400, 1400], options: {
      timeout: 15, # first page render compiles assets, which can exceed the 5s default
      process_timeout: 60, # Chrome can take more than the 10s default to boot on a busy CI runner
      js_errors: true, # fail the spec on any uncaught JS exception
    }

    # Block third-party requests (Stripe, CDNs, etc.), answering the CDN assets pages need with stand-ins
    browser = page.driver.browser
    browser.network.intercept
    browser.on(:request) do |request|
      body, content_type = CDN_STUBS.find { |pattern, _| request.match?(pattern) }&.last

      if request.match?(LOCAL_URL)
        request.continue
      elsif body
        request.respond(body:, responseHeaders: { "Content-Type" => content_type, "Access-Control-Allow-Origin" => "*" })
      else
        request.abort
      end
    end
  rescue Ferrum::ProcessTimeoutError => e # show Chrome's own output when it fails to launch
    raise e, "#{e.message}\nChrome output:\n#{e.output}"
  end
end
