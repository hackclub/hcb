# frozen_string_literal: true

require "twilio-ruby"

class TwilioVerificationService
  CLIENT = Twilio::REST::Client.new(
    Credentials.fetch(:TWILIO, :SMS_VERIFY, :ACCOUNT_SID),
    Credentials.fetch(:TWILIO, :SMS_VERIFY, :AUTH_TOKEN)
  )

  # This isn't private/sensitive so it's okay to keep here
  VERIFY_SERVICE_ID = Credentials.fetch(:TWILIO, :SMS_VERIFY, :SERVICE_ID, fallback: "VAe30d49e92f634419aacdc8648948dc75")

  # Twilio error codes for geographic restrictions on SMS delivery
  GEO_RESTRICTION_ERROR_CODES = %w[21408 21612].freeze

  class UnsupportedCountryError < StandardError; end

  def send_verification_request(phone_number)
    CLIENT.verify
          .services(VERIFY_SERVICE_ID)
          .verifications
          .create(to: phone_number, channel: "sms")
  rescue => e
    if GEO_RESTRICTION_ERROR_CODES.any? { |code| e.message.include?("errors/#{code}") }
      raise UnsupportedCountryError, "SMS verification is not available for your phone number's country."
    end
    unless TwilioMessageService::EXPECTED_TWILIO_ERRORS.any? { |code| e.message.include?("errors/#{code}") }
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
