# frozen_string_literal: true

require "rails_helper"

RSpec.describe TwilioVerificationService do
  include TwilioSupport

  let(:phone_number) { "+18005550100" }
  let(:verifications) { double("verifications") }

  before do
    allow(TwilioVerificationService::CLIENT).to(
      receive_message_chain(:verify, :services, :verifications).and_return(verifications)
    )
    allow(Rails.error).to receive(:report)
  end

  def send_verification
    described_class.new.send_verification_request(phone_number)
  end

  describe "#send_verification_request" do
    it "sends an SMS verification to the number" do
      allow(verifications).to receive(:create).and_return(double("verification"))

      send_verification

      expect(verifications).to have_received(:create).with(to: phone_number, channel: "sms")
    end

    it "explains a landline number without reporting it" do
      allow(verifications).to receive(:create).and_raise(twilio_rest_error(code: 60205, status: 403))

      expect { send_verification }.to raise_error(TwilioVerificationService::DeliveryFailed) do |error|
        expect(error.code).to eq("60205")
        expect(error.reason).to eq("that number is a landline and can't receive text messages")
      end
      expect(Rails.error).not_to have_received(:report)
    end

    it "explains an invalid number" do
      allow(verifications).to receive(:create).and_raise(twilio_rest_error(code: 60200))

      expect { send_verification }.to raise_error(TwilioVerificationService::DeliveryFailed) do |error|
        expect(error.code).to eq("60200")
        expect(error.reason).to eq("that isn't a valid phone number")
      end
    end

    it "raises CountryNotSupported for an unsupported destination country" do
      allow(verifications).to receive(:create).and_raise(twilio_rest_error(code: 21408))

      expect { send_verification }.to raise_error(TwilioVerificationService::CountryNotSupported) do |error|
        expect(error.code).to eq("21408")
        expect(error).to be_a(TwilioVerificationService::DeliveryFailed)
      end
      expect(Rails.error).not_to have_received(:report)
    end

    it "reports an unknown Twilio error and surfaces a generic reason" do
      twilio_error = twilio_rest_error(code: 60999, status: 500)
      allow(verifications).to receive(:create).and_raise(twilio_error)

      expect { send_verification }.to raise_error(TwilioVerificationService::DeliveryFailed) do |error|
        expect(error.code).to eq("60999")
        expect(error.reason).to eq(TwilioVerificationService::GENERIC_DELIVERY_ERROR)
      end
      expect(Rails.error).to have_received(:report).with(twilio_error)
    end

    it "reports and re-raises errors that aren't from Twilio's API" do
      allow(verifications).to receive(:create).and_raise(Faraday::ConnectionFailed, "connection refused")

      expect { send_verification }.to raise_error(Faraday::ConnectionFailed)
      expect(Rails.error).to have_received(:report).with(an_instance_of(Faraday::ConnectionFailed))
    end
  end
end
