# frozen_string_literal: true

require "twilio-ruby"

class TwilioVerificationService
  CLIENT = Twilio::REST::Client.new(
    Credentials.fetch(:TWILIO, :SMS_VERIFY, :ACCOUNT_SID),
    Credentials.fetch(:TWILIO, :SMS_VERIFY, :AUTH_TOKEN)
  )

  # This isn't private/sensitive so it's okay to keep here
  VERIFY_SERVICE_ID = Rails.env.production? || ENV["USE_PROD_CREDENTIALS"]&.downcase == "true" ? "VAa06a66dad4c1ca3c199a46334ff11945" : "VAe30d49e92f634419aacdc8648948dc75"

  def send_verification_request(phone_number)
    CLIENT.verify
          .services(VERIFY_SERVICE_ID)
          .verifications
          .create(to: phone_number, channel: "sms")
  end

  def check_verification_token(phone_number, code)
    verification = CLIENT.verify
                         .services(VERIFY_SERVICE_ID)
                         .verification_checks
                         .create(to: phone_number, code:)
    verification.status == "approved"
  end

end
