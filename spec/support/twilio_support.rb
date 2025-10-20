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
end
