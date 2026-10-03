# frozen_string_literal: true

require "capybara/cuprite"

# Capybara pings its local app server before each session
WebMock.disable_net_connect!(allow_localhost: true)

# Skip config/puma.rb, which fetches Doppler secrets when DOPPLER_TOKEN is set
Capybara.server = :puma, { Silent: true, config_files: ["-"] }

LOCAL_URL = /\Ahttp:\/\/127\.0\.0\.1:\d+\//
# <emoji-picker> downloads its emoji list from jsdelivr; ASCII since Ferrum sends character count as content-length
EMOJI_DATA = [{ annotation: "smile", emoji: ":)", group: 0, order: 1, version: 1 }].to_json
EXTERNAL_STUBS = {
  /\Ahttps:\/\/cdn\.jsdelivr\.net\/npm\/emoji-picker-element-data@/ => EMOJI_DATA,
  /\Ahttps:\/\/blog\.hcb\.hackclub\.com\/api\/unreads/              => { count: 0 }.to_json, # sidebar changelog badge
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
      process_timeout: 30, # Chrome can take longer than the 10s default to launch on a cold CI runner
      js_errors: true, # fail the spec on any uncaught JS exception
    }

    # Block third-party requests (Stripe, CDNs, etc.), answering the ones pages need with stand-ins
    browser = page.driver.browser
    cors_headers = { "Access-Control-Allow-Origin" => page.server.base_url, "Access-Control-Allow-Credentials" => "true" }
    browser.network.intercept
    browser.on(:request) do |request|
      stub = EXTERNAL_STUBS.find { |pattern, _| request.match?(pattern) }&.last

      if request.match?(LOCAL_URL)
        request.continue
      elsif stub
        request.respond(body: stub, responseHeaders: { "Content-Type" => "application/json", **cors_headers })
      else
        request.abort
      end
    end

    # Stimulus catches errors thrown by controllers and only logs them, so js_errors misses them
    @console_errors = []
    browser.on("Runtime.consoleAPICalled") do |params|
      @console_errors << params["args"].map { |arg| arg["value"] || arg["description"] }.join(" ") if params["type"] == "error"
    end
  rescue Ferrum::ProcessTimeoutError => e # show Chrome's own output when it fails to launch
    raise e, "#{e.message}\nChrome output:\n#{e.output}"
  end

  config.after(:each, type: :system) do
    expect(@console_errors).to be_empty, "Browser console errors:\n#{@console_errors.join("\n")}"
  end
end
