# frozen_string_literal: true

require "capybara/cuprite"

# Capybara pings its local app server before each session
WebMock.disable_net_connect!(allow_localhost: true)

# Skip config/puma.rb, which fetches Doppler secrets when DOPPLER_TOKEN is set
Capybara.server = :puma, { Silent: true, config_files: ["-"] }

RSpec.configure do |config|
  config.before(:each, type: :system) do
    driven_by :cuprite, screen_size: [1400, 1400], options: {
      timeout: 15, # first page render compiles assets, which can exceed the 5s default
      js_errors: true, # fail the spec on any uncaught JS exception
      url_whitelist: [/\Ahttp:\/\/127\.0\.0\.1:\d+\//], # block third-party scripts (Stripe, CDNs, etc.)
    }
  end
end
