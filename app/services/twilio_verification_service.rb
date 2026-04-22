# frozen_string_literal: true

require "twilio-ruby"

class TwilioVerificationService
  CLIENT = Twilio::REST::Client.new(
    Credentials.fetch(:TWILIO, :SMS_VERIFY, :ACCOUNT_SID),
    Credentials.fetch(:TWILIO, :SMS_VERIFY, :AUTH_TOKEN)
  )

  # This isn't private/sensitive so it's okay to keep here
  VERIFY_SERVICE_ID = Credentials.fetch(:TWILIO, :SMS_VERIFY, :SERVICE_ID, fallback: "VAe30d49e92f634419aacdc8648948dc75")

  # 21408, 21612: geographic permission errors — Twilio cannot deliver to this country
  COUNTRY_NOT_SUPPORTED_ERRORS = %w[21408 21612].freeze
  # 60410: Twilio has flagged this number for fraud — swallow silently
  SILENT_ERRORS = %w[60410].freeze

  class CountryNotSupportedError < StandardError; end

  def send_verification_request(phone_number)
    CLIENT.verify
          .services(VERIFY_SERVICE_ID)
          .verifications
          .create(to: phone_number, channel: "sms")
  rescue => e
    if COUNTRY_NOT_SUPPORTED_ERRORS.any? { |code| e.message.include?("errors/#{code}") }
      raise CountryNotSupportedError
    elsif SILENT_ERRORS.any? { |code| e.message.include?("errors/#{code}") }
      nil
    else
      Rails.error.report(e)
      raise
    end
  end

  def check_verification_token(phone_number, code)
    verification = CLIENT.verify
                         .services(VERIFY_SERVICE_ID)
                         .verification_checks
                         .create(to: phone_number, code:)
    verification.status == "approved"
  rescue => e
    unless TwilioMessageService::EXPECTED_TWILIO_ERRORS.any? { |code| e.message.include?("errors/#{code}") }
      Rails.error.report(e)
      raise
    end
  end

end
