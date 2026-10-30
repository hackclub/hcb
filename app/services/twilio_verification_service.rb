# frozen_string_literal: true

require "twilio-ruby"

class TwilioVerificationService
  CLIENT = Twilio::REST::Client.new(
    Credentials.fetch(:TWILIO, :SMS_VERIFY, :ACCOUNT_SID),
    Credentials.fetch(:TWILIO, :SMS_VERIFY, :AUTH_TOKEN)
  )

  # This isn't private/sensitive so it's okay to keep here
  VERIFY_SERVICE_ID = Credentials.fetch(:TWILIO, :SMS_VERIFY, :SERVICE_ID, fallback: "VAe30d49e92f634419aacdc8648948dc75")

  # Twilio error codes for countries where SMS delivery is not supported
  UNSUPPORTED_COUNTRY_ERRORS = %w[21408 21612 60220].freeze

  # Twilio error codes we know how to explain to the user when a verification
  # code can't be sent to their number. Anything else is reported and surfaced
  # with a generic reason. https://www.twilio.com/docs/api/errors/<code>
  DELIVERY_ERRORS = {
    "21211" => "that isn't a valid phone number",
    "60200" => "that isn't a valid phone number",
    "21614" => "that number can't receive text messages",
    "60205" => "that number is a landline and can't receive text messages",
    "60600" => "that number doesn't appear to be active with a carrier",
    "21610" => "that number has opted out of receiving texts from us",
    "60410" => "text messages to that number are temporarily blocked by our SMS provider",
    "60605" => "text messages to that number are blocked by our SMS provider",
    "60203" => "too many codes have been sent to that number; wait 10 minutes and try again",
    "60212" => "too many codes were requested for that number in a short period"
  }.freeze

  GENERIC_DELIVERY_ERROR = "our SMS provider couldn't deliver to that number"

  # Raised when Twilio refuses to send a verification code. `code` is Twilio's
  # numeric error code and `reason` is a short, user-facing explanation.
  class DeliveryFailed < StandardError
    attr_reader :code, :reason

    def initialize(code, reason)
      @code = code
      @reason = reason
      super("Twilio error #{code}: #{reason}")
    end

  end

  class CountryNotSupported < DeliveryFailed
    def initialize(code)
      super(code, "SMS isn't available in that number's country")
    end

  end

  def send_verification_request(phone_number)
    CLIENT.verify
          .services(VERIFY_SERVICE_ID)
          .verifications
          .create(to: phone_number, channel: "sms")
  rescue Twilio::REST::RestError => e
    code = e.code.to_s

    raise CountryNotSupported.new(code) if UNSUPPORTED_COUNTRY_ERRORS.include?(code)

    reason = DELIVERY_ERRORS[code]
    Rails.error.report(e) if reason.nil?
    raise DeliveryFailed.new(code, reason || GENERIC_DELIVERY_ERROR)
  rescue => e
    Rails.error.report(e)
    raise
  end

  def check_verification_token(phone_number, code)
    verification = CLIENT.verify
                         .services(VERIFY_SERVICE_ID)
                         .verification_checks
                         .create(to: phone_number, code:)
    verification.status == "approved"
  rescue => e
    unless ::TwilioMessageService::EXPECTED_TWILIO_ERRORS.any? { |code| e.message.include?("errors/#{code}") }
      Rails.error.report(e)
      raise
    end
  end

end
