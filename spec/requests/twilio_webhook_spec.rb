# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Twilio Webhook", type: :request do
  let(:auth_token) { ENV.fetch("TWILIO__AUTH_TOKEN") }
  let(:validator) { Twilio::Security::RequestValidator.new(auth_token) }
  let(:webhook_url) { "http://www.example.com/twilio/webhook" }
  let(:params) do
    {
      "From"     => "+1234567890",
      "To"       => "+0987654321",
      "Body"     => "Hello",
      "NumMedia" => "0"
    }
  end
  let(:xml_headers) { { "Accept" => "application/xml" } }

  describe "POST /twilio/webhook" do
    context "with a valid Twilio signature" do
      it "returns 200 and enqueues the processing job" do
        signature = validator.build_signature_for(webhook_url, params)

        expect {
          post "/twilio/webhook",
               params:,
               headers: xml_headers.merge("X-Twilio-Signature" => signature)
        }.to have_enqueued_job(Twilio::ProcessWebhookJob)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("<Response></Response>")
      end
    end

    context "with an invalid Twilio signature" do
      it "returns 403 and does not process the webhook" do
        expect(TwilioController.method_defined?(:webhook)).to be(true)
        expect_any_instance_of(TwilioController).not_to receive(:webhook)

        post "/twilio/webhook",
             params:,
             headers: xml_headers.merge("X-Twilio-Signature" => "invalidsignature")

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "with no Twilio signature" do
      it "returns 403 and does not process the webhook" do
        expect(TwilioController.method_defined?(:webhook)).to be(true)
        expect_any_instance_of(TwilioController).not_to receive(:webhook)

        post "/twilio/webhook",
             params:,
             headers: xml_headers

        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
