# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Docuseal Webhook", type: :request do
  let(:webhook_secret) { "test_docuseal_webhook_secret" }
  let(:payload) do
    {
      event_type: "form.completed",
      data: { submission_id: 1, role: "signer" }
    }
  end

  around do |example|
    original = ENV["DOCUSEAL__WEBHOOK_SECRET"]
    ENV["DOCUSEAL__WEBHOOK_SECRET"] = webhook_secret
    example.run
  ensure
    ENV["DOCUSEAL__WEBHOOK_SECRET"] = original
  end

  describe "POST /docuseal/webhook" do
    context "with a valid Docuseal secret" do
      it "returns 200 with success" do
        post "/docuseal/webhook",
             params: payload,
             headers: { "X-Docuseal-Secret" => webhook_secret }

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["success"]).to be true
      end
    end

    context "with an invalid Docuseal secret" do
      it "returns 200 with failure" do
        post "/docuseal/webhook",
             params: payload,
             headers: { "X-Docuseal-Secret" => "wrong_secret" }

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["success"]).to be false
      end
    end

    context "with no Docuseal secret" do
      it "returns 200 with failure" do
        post "/docuseal/webhook",
             params: payload

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["success"]).to be false
      end
    end
  end
end
