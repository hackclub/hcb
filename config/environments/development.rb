# frozen_string_literal: true

require "active_support/core_ext/integer/time"
require_relative "../../app/lib/credentials"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Prepare the ingress controller used to receive mail
  config.action_mailbox.ingress = :sendgrid

  # Make code changes take effect immediately without server restart.
  config.enable_reloading = true

  # Do not eager load code on boot.
  config.eager_load = false

  # Show full error reports.
  config.consider_all_requests_local = true

  # Allow any host in development
  # https://www.fngtps.com/2019/rails6-blocked-host/
  config.hosts.clear

  # Enable server timing
  config.server_timing = true

  # Enable/disable Action Controller caching. By default Action Controller caching is disabled.
  # Run rails dev:cache to toggle Action Controller caching.
  if Rails.root.join("tmp/caching-dev.txt").exist?
    config.action_controller.perform_caching = true
    config.action_controller.enable_fragment_cache_logging = true
    config.public_file_server.headers = {
      "Cache-Control" => "public, max-age=#{2.days.to_i}"
    }

    config.cache_store = :memory_store
  else
    config.action_controller.perform_caching = false

    config.cache_store = :null_store
  end

  # Store uploaded files on the local file system (see config/storage.yml for options).
  config.active_storage.service = :local

  # Don't care if the mailer can't send.
  config.action_mailer.raise_delivery_errors = false

  # Make template changes take effect immediately.
  config.action_mailer.perform_caching = false

  # Configure the URL host for links
  config.action_mailer.default_url_options = {
    host: Credentials.fetch(:TEST_URL_HOST)
  }

  Rails.application.routes.default_url_options[:host] = Credentials.fetch(:TEST_URL_HOST)

  # Print deprecation notices to the Rails logger.
  config.active_support.deprecation = :log

  # Raise an error on page load if there are pending migrations.
  config.active_record.migration_error = :page_load

  # Highlight code that triggered database queries in logs.
  config.active_record.verbose_query_logs = true

  # Append comments with runtime information tags to SQL queries in logs.
  config.active_record.query_log_tags_enabled = true

  # Highlight code that enqueued background job in logs.
  config.active_job.verbose_enqueue_logs = true

  # Raises error for missing translations.
  # config.i18n.raise_on_missing_translations = true

  # Annotate rendered view with file names.
  config.action_view.annotate_rendered_view_with_filenames = true

  # Uncomment if you wish to allow Action Cable access from any origin.
  # config.action_cable.disable_request_forgery_protection = true

  config.action_mailer.show_previews = true


  # SMTP config
  config.action_mailer.delivery_method = :letter_opener_web

  # Bullet for finding N+1s
  config.after_initialize do
    Bullet.enable        = true
    Bullet.console       = true
    Bullet.rails_logger  = true
  end

  if ENV["RAILS_LOG_TO_STDOUT"].present?
    config.logger = ActiveSupport::TaggedLogging.new(ActiveSupport::Logger.new($stdout))
  end
end
