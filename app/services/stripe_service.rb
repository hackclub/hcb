# frozen_string_literal: true

module StripeService
  def self.mode
    if Rails.env.production?
      :live
    else
      :test
    end
  end

  def self.publishable_key
    Credentials.fetch(:STRIPE, self.mode, :PUBLISHABLE_KEY)
  end

  def self.secret_key
    Credentials.fetch(:STRIPE, self.mode, :SECRET_KEY)
  end

  def self.physical_bundle_ids
    {
      white: Credentials.fetch(:STRIPE, self.mode, :PHYSICAL_BUNDLE_IDS, :US_VISA_CREDIT_WHITE),
      black: Credentials.fetch(:STRIPE, self.mode, :PHYSICAL_BUNDLE_IDS, :US_VISA_CREDIT_BLACK)
    }
  end

  def self.construct_webhook_event(payload, sig_header, signing_secret_key = :primary)
    signing_secret = Credentials.fetch(:STRIPE, self.mode, :WEBHOOK_SIGNING_SECRETS, signing_secret_key)

    # Don't check signatures if a signing secret wasn't provided
    # TODO: don't allow a blank signing secret in production
    if signing_secret.blank?
      Stripe::Event.construct_from(JSON.parse(payload, symbolize_names: true))
    else
      Stripe::Webhook.construct_event(payload, sig_header, signing_secret)
    end
  end

  include Stripe

  module StatementDescriptor
    # stripe enforces that statement descriptors are limited to this long
    PREFIX = "HCB* " # This must be the same as the prefix in the Stripe dashboard
    CHAR_LIMIT = 22
    SUFFIX_CHAR_LIMIT = CHAR_LIMIT - PREFIX.length

    def self.clean(str)
      str = ActiveSupport::Inflector.transliterate(str)
                                    .to_s.gsub(/[^a-zA-Z0-9\-_ ]/, "")
      return str if str.present?

      "HCB"
    end

    def self.format(str, as: :full)
      str = clean(str)

      case as
      when :suffix
        str[0...SUFFIX_CHAR_LIMIT].strip
      when :full
        "#{PREFIX}#{str}"[0...CHAR_LIMIT].strip
      else
        raise ArgumentError, "Invalid format: #{as}"
      end
    end
  end
end
