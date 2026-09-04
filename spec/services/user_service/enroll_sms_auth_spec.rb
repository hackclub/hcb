# frozen_string_literal: true

require "rails_helper"

RSpec.describe UserService::EnrollSmsAuth do
  # Old enough to pass the fresh-account guard on `start_verification`. The
  # number is set after creation because `User#format_number` (`before_create`)
  # strips the `+` that `start_verification` requires.
  let(:user) do
    create(:user, created_at: 2.days.ago).tap { |u| u.update!(phone_number: "+18005550100") }
  end
  let(:verification_service) { instance_double(TwilioVerificationService) }

  before do
    allow(TwilioVerificationService).to receive(:new).and_return(verification_service)
  end

  describe "#start_verification" do
    it "sends a verification code to the user's number" do
      allow(verification_service).to receive(:send_verification_request)

      described_class.new(user).start_verification

      expect(verification_service).to have_received(:send_verification_request).with(user.phone_number)
    end

    it "tells the user why Twilio couldn't send the code and what to do next" do
      allow(verification_service).to(
        receive(:send_verification_request)
          .and_raise(TwilioVerificationService::DeliveryFailed.new("60205", "that number is a landline and can't receive text messages"))
      )

      expect { described_class.new(user).start_verification }.to raise_error(
        UserService::EnrollSmsAuth::SMSEnrollmentError,
        "We couldn't send a verification code to your phone number: that number is a landline and can't receive text messages (Twilio error 60205). " \
        "Please try a different phone number, or contact hcb@hackclub.com for further assistance."
      )
    end

    it "handles unsupported countries the same way" do
      allow(verification_service).to(
        receive(:send_verification_request)
          .and_raise(TwilioVerificationService::CountryNotSupported.new("21408"))
      )

      expect { described_class.new(user).start_verification }.to raise_error(
        UserService::EnrollSmsAuth::SMSEnrollmentError,
        /SMS isn't available in that number's country \(Twilio error 21408\)\. Please try a different phone number, or contact hcb@hackclub\.com/
      )
    end
  end
end
