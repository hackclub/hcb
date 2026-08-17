# frozen_string_literal: true

module TwilioSupport
  # Replaces `TwilioVerificationService` with a double that accepts a
  # verification send for `phone_number` and — when a spec exercises the code
  # exchange — a successful check of `code`.
  def stub_twilio_sms_verification(phone_number:, code: nil)
    verification_service = instance_double(TwilioVerificationService)

    allow(verification_service).to(
      receive(:send_verification_request)
        .with(phone_number)
    )

    if code
      allow(verification_service).to(
        receive(:check_verification_token)
          .with(phone_number, code)
          .and_return(true)
      )
    end

    allow(TwilioVerificationService).to receive(:new).and_return(verification_service)
  end
end
