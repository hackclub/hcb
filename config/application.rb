# frozen_string_literal: true

require_relative "boot"

require "rails/all"
require_relative "../app/lib/credentials"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Bank
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.2

    Credentials.load if ENV["DOPPLER_TOKEN"]

    if ENV["USE_PROD_CREDENTIALS"]&.downcase == "true"
      config.credentials.content_path = Rails.root.join("config/credentials/production.yml.enc")
      config.credentials.key_path = Rails.root.join("config/credentials/production.key")
      raise StandardError, "USE_PROD_CREDENTIALS is set to true but config/credentials/production.key is missing" unless File.file?(config.credentials.key_path)
    end

    config.action_mailer.default_url_options = {
      host: Credentials.fetch(:LIVE_URL_HOST)
    }

    # SMTP config
    config.action_mailer.smtp_settings = {
      user_name: Credentials.fetch(:SMTP, :USERNAME),
      password: Credentials.fetch(:SMTP, :PASSWORD),
      address: Credentials.fetch(:SMTP, :ADDRESS),
      domain: Credentials.fetch(:SMTP, :DOMAIN),
      port: Credentials.fetch(:SMTP, :PORT),
      authentication: :plain
    }

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration can go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded after loading
    # the framework and any gems in your application.

    # Customize generators...
    config.generators do |g|
      g.test_framework false
    end

    config.react.camelize_props = true

    config.active_support.cache_format_version = 7.1

    config.autoload_lib(ignore: %w(assets tasks))
    config.eager_load_paths << "#{config.root}/spec/mailers/previews"

    config.action_view.form_with_generates_remote_forms = false

    config.exceptions_app = routes

    config.to_prepare do
      Doorkeeper::AuthorizationsController.layout "application"
    end

    config.active_storage.variant_processor = :mini_magick

    # TODO: Pre-load grape API
    # ::API::V3.compile!

    config.action_mailer.deliver_later_queue_name = "critical"
    config.action_mailbox.queues.routing = "default"
    config.action_mailbox.queues.incineration = "low"
    config.active_storage.queues.analysis = "low"
    config.active_storage.queues.purge = "low"
    config.active_storage.queues.mirror = "low"

    # console1984 / audits1984
    config.console1984.ask_for_username_if_empty = true
    config.console1984.incinerate = false

    # Custom configuration for application-wide constants
    #
    # Usually, it's best to locate constants within the class/module it's used.
    # However, some constants don't really have a "home" within the codebase.
    # Thus, they're configured in the `config/constants.yml` file. Updating this
    # file will require a server restart to take effect.
    #
    # Usage: `Rails.configuration.constants[:key]`
    #
    # https://guides.rubyonrails.org/configuring.html#custom-configuration
    config.constants = config_for(:constants)

    # See https://jordanhollinger.com/2023/11/11/rails-strict-loading/ for context
    config.active_record.action_on_strict_loading_violation = :log

    # setting up ActiveRecord's encryption: https://guides.rubyonrails.org/active_record_encryption.html#setup
    config.active_record.encryption.primary_key = Credentials.fetch(:ACTIVE_RECORD, :ENCRYPTION, :PRIMARY_KEY)
    config.active_record.encryption.deterministic_key = Credentials.fetch(:ACTIVE_RECORD, :ENCRYPTION, :DETERMINISTIC_KEY)
    config.active_record.encryption.key_derivation_salt = Credentials.fetch(:ACTIVE_RECORD, :ENCRYPTION, :KEY_DERIVATION_SALT)

  end
end
