# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Stripe Webhook", type: :request do
  let(:webhook_secret) { "whsec_test_stripe_webhook_secret" }
  let(:payload) do
    {
      id: "evt_test",
      object: "event",
      type: "charge.updated",
      data: { object: { id: "ch_test", metadata: {} } }
    }.to_json
  end

  around do |example|
    original = ENV["STRIPE__TEST__WEBHOOK_SIGNING_SECRETS__PRIMARY"]
    ENV["STRIPE__TEST__WEBHOOK_SIGNING_SECRETS__PRIMARY"] = webhook_secret
    example.run
  ensure
    ENV["STRIPE__TEST__WEBHOOK_SIGNING_SECRETS__PRIMARY"] = original
  end

  def stripe_signature(body, timestamp: Time.now)
    signature = Stripe::Webhook::Signature.compute_signature(timestamp, body, webhook_secret)
    Stripe::Webhook::Signature.generate_header(timestamp, signature)
  end

  describe "POST /stripe/webhook" do
    context "with a valid Stripe signature" do
      it "returns 204" do
        post "/stripe/webhook",
             params: payload,
             headers: { "Stripe-Signature" => stripe_signature(payload), "Content-Type" => "application/json" }

        expect(response).to have_http_status(:no_content)
      end
    end

    context "with an invalid Stripe signature" do
      it "returns 400 and does not process the webhook" do
        expect(StripeController.private_method_defined?(:handle_charge_updated)).to be(true)
        expect_any_instance_of(StripeController).not_to receive(:handle_charge_updated)

        post "/stripe/webhook",
             params: payload,
             headers: { "Stripe-Signature" => "t=1234567890,v1=invalidsignature", "Content-Type" => "application/json" }

        expect(response).to have_http_status(:bad_request)
      end
    end

    context "with no Stripe signature" do
      it "returns 400 and does not process the webhook" do
        expect(StripeController.private_method_defined?(:handle_charge_updated)).to be(true)
        expect_any_instance_of(StripeController).not_to receive(:handle_charge_updated)

        post "/stripe/webhook",
             params: payload,
             headers: { "Content-Type" => "application/json" }

        expect(response).to have_http_status(:bad_request)
      end
    end
  end
end
