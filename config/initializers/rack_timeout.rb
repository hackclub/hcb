# frozen_string_literal: true

# config/initializers/rack_timeout.rb

# insert middleware wherever you want in the stack, optionally pass
# initialization arguments, or use environment variables
unless Rails.env.development?
  Rails.application.config.middleware.insert_before Rack::Runtime, Rack::Timeout, service_timeout: 30
end
