# frozen_string_literal: true

class Ahoy::Store < Ahoy::DatabaseStore
end

# set to true for JavaScript tracking
Ahoy.api = true

# set to true for geocoding
# we recommend configuring local geocoding first
# see https://github.com/ankane/ahoy#geocoding
Ahoy.geocode = false

Ahoy.exclude_method = ->(controller, request) { true }

# Nothing in the browser needs to read these (the analytics Stimulus
# controller only posts events), so keep them out of reach of scripts.
Ahoy.cookie_options = { httponly: true }
