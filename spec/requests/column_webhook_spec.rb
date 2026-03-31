# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Column Webhook", type: :request do
  let(:webhook_secret) { "test_column_webhook_secret" }
  let(:payload) { { type: "ach.incoming_transfer.settled", data: { id: "acht_test", account_number_id: "acno_test", amount: 1000 } }.to_json }

  around do |example|
    original = ENV["COLUMN__SANDBOX__WEBHOOK_SECRET"]
    ENV["COLUMN__SANDBOX__WEBHOOK_SECRET"] = webhook_secret
    example.run
  ensure
    ENV["COLUMN__SANDBOX__WEBHOOK_SECRET"] = original
  end

  def column_signature(body)
    OpenSSL::HMAC.hexdigest("SHA256", webhook_secret, body)
  end

  describe "POST /webhooks/column" do
    context "with a valid Column signature" do
      it "does not return 400" do
        post "/webhooks/column",
             params: payload,
             headers: { "Column-Signature" => column_signature(payload), "Content-Type" => "application/json" }

        expect(response).to have_http_status(:ok)
      end
    end

    context "with an invalid Column signature" do
      it "returns 400" do
        post "/webhooks/column",
             params: payload,
             headers: { "Column-Signature" => "invalidsignature", "Content-Type" => "application/json" }

        expect(response).to have_http_status(:bad_request)
      end
    end

    context "with no Column signature" do
      it "returns 400" do
        post "/webhooks/column",
             params: payload,
             headers: { "Content-Type" => "application/json" }

        expect(response).to have_http_status(:bad_request)
      end
    end
  end
end
