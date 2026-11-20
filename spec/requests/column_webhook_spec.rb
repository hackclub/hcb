# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Column Webhook", type: :request do
  let(:webhook_secret) { "test_column_webhook_secret" }
  let(:payload) do
    {
      type: "ach.incoming_transfer.settled",
      data: { id: "acht_test", account_number_id: "acno_test", amount: 1000, type: "CREDIT", company_name: "ACME", company_entry_description: "PAYROLL" }
    }.to_json
  end

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
      it "processes the webhook and returns 200" do
        event = create(:event)
        allow(ColumnService).to receive(:post).and_return({ "id" => "acno_test", "account_number" => "1234", "routing_number" => "1234", "bic" => "1234" })
        event.create_column_account_number!

        expect do
          post "/webhooks/column",
               params: payload,
               headers: { "Column-Signature" => column_signature(payload), "Content-Type" => "application/json" }
        end.to change { RawPendingColumnTransaction.count }.by(1)

        expect(response).to have_http_status(:ok)
        expect(RawPendingColumnTransaction.last).to have_attributes(column_id: "acht_test", amount_cents: 1000, description: "ACME PAYROLL")
        expect(RawPendingColumnTransaction.last.canonical_pending_transaction.event).to eq(event)
      end
    end

    context "with an invalid Column signature" do
      it "returns 400 and does not process the webhook" do
        expect(Column::WebhooksController.method_defined?(:webhook)).to be(true)
        expect_any_instance_of(Column::WebhooksController).not_to receive(:webhook)

        post "/webhooks/column",
             params: payload,
             headers: { "Column-Signature" => "invalidsignature", "Content-Type" => "application/json" }

        expect(response).to have_http_status(:bad_request)
      end
    end

    context "with no Column signature" do
      it "returns 400 and does not process the webhook" do
        expect(Column::WebhooksController.method_defined?(:webhook)).to be(true)
        expect_any_instance_of(Column::WebhooksController).not_to receive(:webhook)

        post "/webhooks/column",
             params: payload,
             headers: { "Content-Type" => "application/json" }

        expect(response).to have_http_status(:bad_request)
      end
    end
  end
end
