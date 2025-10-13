# frozen_string_literal: true

require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # We don't use Rails' default encrypted credentials in Production. However,
  # Rails doesn't provide an explicit way to disable encrypted credentials.
  # As a workaround, we set `content_path` and `key_path` to an invalid path.
  #
  # Without this workaround, Rails will fallback to `config/credentials.yml.enc`
  # which is NOT used for production. It will then attempt to decrypt that file,
  # resulting in `ActiveSupport::MessageEncryptor::InvalidMessage` on boot.
  #
  # `content_path` and `key_path` are used to create an
  # `ActiveSupport::EncryptedConfiguration` object which is
  # `Rails.application.credentials`. When `EncryptedConfiguration`
  # (subclass of `EncryptedFile`) has either an invalid key or content path,
  # Rails will internally just use an empty string as the decrypted contents of
  # the file.
  #
  # REFERENCES
  # * Where `Rails.application.credentials` is set:
  #   https://github.com/rails/rails/blob/f575fca24a72cf0631c59ed797c575392fbbc527/railties/lib/rails/application.rb#L497-L499
  # * `EncryptedFile#read` raises `MissingContentError`
  #   when missing either a key or content_path.
  #   https://github.com/rails/rails/blob/f575fca24a72cf0631c59ed797c575392fbbc527/activesupport/lib/active_support/encrypted_file.rb#L70-L76
  # * `EncryptedConfiguration#read` (overrides `EncryptedFile#read`) rescues
  #   `MissingContentError` and returns an empty string.
  #   https://github.com/rails/rails/blob/f575fca24a72cf0631c59ed797c575392fbbc527/activesupport/lib/active_support/encrypted_configuration.rb#L64-L66
  #
  # ~ @garyhtou
  config.credentials.content_path = "noop"
  config.credentials.key_path = "noop"

  # Prepare the ingress controller used to receive mail
  config.action_mailbox.ingress = :sendgrid

  # Code is not reloaded between requests.
  config.cache_classes = true

  # Eager load code on boot. This eager loads most of Rails and
  # your application in memory, allowing both threaded web servers
  # and those relying on copy on write to perform better.
  # Rake tasks automatically ignore this option for performance.
  config.eager_load = true

  # Full error reports are disabled and caching is turned on.
  config.consider_all_requests_local       = false
  config.action_controller.perform_caching = true

  # Ensures that a master key has been made available in either ENV["RAILS_MASTER_KEY"]
  # or in config/master.key. This key is used to decrypt credentials (and other encrypted files).
  # config.require_master_key = true

  # Disable serving static files from the `/public` folder by default since
  # Apache or NGINX already handles this.
  config.public_file_server.enabled = ENV["RAILS_SERVE_STATIC_FILES"].present?

  # Compress CSS using a preprocessor.
  # config.assets.css_compressor = :sass
  config.assets.js_compressor = :terser

  # Do not fallback to assets pipeline if a precompiled asset is missed.
  config.assets.compile = false

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  config.asset_host = ENV["ASSET_HOST"]

  # Specifies the header that your server uses for sending files.
  # config.action_dispatch.x_sendfile_header = 'X-Sendfile' # for Apache
  # config.action_dispatch.x_sendfile_header = 'X-Accel-Redirect' # for NGINX

  # Store uploaded files on the local file system (see config/storage.yml for options).
  config.active_storage.service = :amazon

  # Mount Action Cable outside main process or domain.
  # config.action_cable.mount_path = nil
  # config.action_cable.url = 'wss://example.com/cable'
  # config.action_cable.allowed_request_origins = [ 'http://example.com', /http:\/\/example.*/ ]

  # Assume all access to the app is happening through a SSL-terminating reverse proxy.
  # Can be used together with config.force_ssl for Strict-Transport-Security and secure cookies.
  config.assume_ssl = ENV.fetch("RAILS_ASSUME_SSL", false) == "true"

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  config.force_ssl = true

  # Include generic and useful information about system operation, but avoid logging too much
  # information to avoid inadvertent exposure of personally identifiable information (PII).
  config.log_level = :debug

  # Prepend all log lines with the following tags.
  config.log_tags = [:request_id]

  # Use a different cache store in production.
  config.cache_store = :redis_cache_store, { url: ENV["REDIS_CACHE_URL"], ssl_params: { verify_mode: OpenSSL::SSL::VERIFY_NONE } }

  # Use Sidekiq
  config.active_job.queue_adapter = :sidekiq

  config.action_mailer.perform_caching = false

  config.action_mailer.delivery_method = :smtp

  # Ignore bad email addresses and do not raise email delivery errors.
  # Set this to true and configure the email server for immediate delivery to raise delivery errors.
  # config.action_mailer.raise_delivery_errors = false

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Send deprecation notices to registered listeners.
  config.active_support.deprecation = :notify

  # Log disallowed deprecations.
  config.active_support.disallowed_deprecation = :log

  # Tell Active Support which deprecation messages to disallow.
  config.active_support.disallowed_deprecation_warnings = []

  # Use default logging formatter so that PID and timestamp are not suppressed.
  config.log_formatter = ::Logger::Formatter.new

  config.active_storage.routes_prefix = "/storage"

  # Use a different logger for distributed setups.
  # require "syslog/logger"
  # config.logger = ActiveSupport::TaggedLogging.new(Syslog::Logger.new "app-name")

  if ENV["RAILS_LOG_TO_STDOUT"].present?
    logger           = ActiveSupport::Logger.new($stdout)
    logger.formatter = config.log_formatter
    config.logger    = ActiveSupport::TaggedLogging.new(logger)
  end

  # Use lograge to tame log output to AppSignal.
  config.lograge.enabled = true
  config.lograge.ignore_actions = ["Rails::HealthController#show"]
  config.log_tags = [:request_id]
  config.lograge.custom_payload { |controller| { request_id: controller.request.uuid } }
  config.lograge.keep_original_rails_log = true
  config.lograge.logger = Appsignal::Logger.new(
    "rails",
    format: Appsignal::Logger::LOGFMT
  )

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  config.action_mailer.default_url_options = {
    host: Credentials.fetch(:LIVE_URL_HOST)
  }
  Rails.application.routes.default_url_options[:host] = Credentials.fetch(:LIVE_URL_HOST)
end
