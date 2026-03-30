# frozen_string_literal: true

require "active_support/core_ext/integer/time"
require_relative "../../app/lib/credentials"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Prepare the ingress controller used to receive mail
  config.action_mailbox.ingress = :sendgrid

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot for better performance and memory savings (ignored by Rake tasks).
  config.eager_load = true

  # Full error reports are disabled.
  config.consider_all_requests_local = false

  # Turn on fragment caching in view templates.
  config.action_controller.perform_caching = true

  # Cache assets for far-future expiry since they are all digest stamped.
  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }

  # Disable serving static files from the `/public` folder by default since
  # Apache or NGINX already handles this.
  # TODO: public_file_server.enabled defaults to true now, can we delete this and the env var in hatchbox?
  config.public_file_server.enabled = ENV["RAILS_SERVE_STATIC_FILES"].present?

  # TODO: confirm when we are fully off sprockets and delete these config.assets settings
  # Compress CSS using a preprocessor.
  # config.assets.css_compressor = :sass
  config.assets.js_compressor = :terser

  # Do not fallback to assets pipeline if a precompiled asset is missed.
  config.assets.compile = false


  # Store uploaded files on the local file system (see config/storage.yml for options).
  config.active_storage.service = :local


  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  config.force_ssl = true

  # Use default logging formatter so that PID and timestamp are not suppressed.
  # This is an old Rails 7.0 default, but leaving it in because we depend on it below
  config.log_formatter = ::Logger::Formatter.new

  # Log to STDOUT with the current request id as a default log tag.
  config.log_tags = [:request_id]
  if ENV["RAILS_LOG_TO_STDOUT"].present?
    logger           = ActiveSupport::Logger.new($stdout)
    logger.formatter = config.log_formatter
    config.logger    = ActiveSupport::TaggedLogging.new(logger)
  end

  # Change to "debug" to log everything (including potentially personally-identifiable information!)
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "debug")

  # Prevent health checks from clogging up the logs.
  config.silence_healthcheck_path = "/up"

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Replace the default in-process memory cache store with a durable alternative.
  config.cache_store = :redis_cache_store, { url: ENV["REDIS_CACHE_URL"], ssl_params: { verify_mode: OpenSSL::SSL::VERIFY_NONE } }

  # Use a real queuing backend for Active Job (and separate queues per environment).
  # config.active_job.queue_adapter     = :resque
  # config.active_job.queue_name_prefix = "bank_production"


  config.action_mailer.delivery_method = :smtp

  # Ignore bad email addresses and do not raise email delivery errors.
  # Set this to true and configure the email server for immediate delivery to raise delivery errors.
  # config.action_mailer.raise_delivery_errors = false

  # Set host to be used by links generated in mailer templates.
  config.action_mailer.default_url_options = {
    host: Credentials.fetch(:LIVE_URL_HOST)
  }
  Rails.application.routes.default_url_options[:host] = Credentials.fetch(:LIVE_URL_HOST)

  # Specify outgoing SMTP server. Remember to add smtp/* credentials via rails credentials:edit.
  # config.action_mailer.smtp_settings = {
  #   user_name: Rails.application.credentials.dig(:smtp, :user_name),
  #   password: Rails.application.credentials.dig(:smtp, :password),
  #   address: "smtp.example.com",
  #   port: 587,
  #   authentication: :plain
  # }

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true


  config.active_storage.routes_prefix = "/storage"


  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Only use :id for inspections in production.
  config.active_record.attributes_for_inspect = [:id]

  # Enable DNS rebinding protection and other `Host` header attacks.
  # config.hosts = [
  #   "example.com",     # Allow requests from example.com
  #   /.*\.example\.com/ # Allow requests from subdomains like `www.example.com`
  # ]
  #
  # Skip DNS rebinding protection for the default health check endpoint.
  # config.host_authorization = { exclude: ->(request) { request.path == "/up" } }
end
