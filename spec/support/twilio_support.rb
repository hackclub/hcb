# frozen_string_literal: true

module TwilioSupport
  def stub_twilio_sms_verification(phone_number:, code:)
    verification_service = instance_double(TwilioVerificationService)

    allow(verification_service).to(
      receive(:send_verification_request)
        .with(phone_number)
    )

    allow(verification_service).to(
      receive(:check_verification_token)
        .with(phone_number, code)
        .and_return(true)
    )

    allow(TwilioVerificationService).to receive(:new).and_return(verification_service)
  end

  # Builds the exception twilio-ruby raises for a non-2xx API response, shaped
  # like Twilio's real error body so `code`/`more_info` behave as in production.
  def twilio_rest_error(code:, status: 400, message: "Twilio error #{code}")
    body = {
      code:,
      message:,
      more_info: "https://www.twilio.com/docs/errors/#{code}",
      status:
    }.to_json

    Twilio::REST::RestError.new("Unable to create record", Twilio::Response.new(status, body))
  end
end
