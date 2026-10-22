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

    context "with an issuing_authorization.request event" do
      let(:event) { create(:event) }
      let(:stripe_card) { create(:stripe_card, :with_stripe_id, event:) }
      let(:authorization) { build(:stripe_authorization, card: { id: stripe_card.stripe_id }) }
      let(:payload) do
        {
          id: "evt_test",
          object: "event",
          type: "issuing_authorization.request",
          data: { object: authorization }
        }.to_json
      end

      def post_webhook
        post "/stripe/webhook",
             params: payload,
             headers: { "Stripe-Signature" => stripe_signature(payload), "Content-Type" => "application/json" }
      end

      it "responds with the metadata to set on a declined authorization" do
        post_webhook

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to eq(
          "approved" => false,
          "metadata" => {
            "current_balance_available" => "0",
            "declined_reason"           => "inadequate_balance"
          }
        )
      end

      it "responds with the metadata to set on an approved authorization" do
        create(:canonical_pending_transaction, amount_cents: 1000, event:, fronted: true)

        post_webhook

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to eq(
          "approved" => true,
          "metadata" => { "current_balance_available" => "1000" }
        )
      end
    end

    context "with a recurring donation's invoice.paid event" do
      let(:event) { create(:event) }
      let!(:recurring_donation) do
        RecurringDonation.create!(event:, name: "Donor", email: "donor@example.com", amount: 10_00, stripe_subscription_id: "sub_test")
      end

      def invoice_paid(event_id, payment_intent: "pi_test")
        {
          id: event_id,
          object: "event",
          type: "invoice.paid",
          data: {
            object: {
              id: "in_#{payment_intent}", object: "invoice", subscription: "sub_test", charge: "ch_#{payment_intent}",
              payment_intent:, amount_due: 10_00, amount_paid: 10_00
            }
          }
        }.to_json
      end

      def post_webhook(body)
        post "/stripe/webhook",
             params: body,
             headers: { "Stripe-Signature" => stripe_signature(body), "Content-Type" => "application/json" }
      end

      def fronted_cents
        rpdt_ids = RawPendingDonationTransaction.where(donation_transaction_id: recurring_donation.donations.ids.map(&:to_s)).ids
        CanonicalPendingTransaction.where(raw_pending_donation_transaction_id: rpdt_ids, fronted: true).sum(:amount_cents)
      end

      before do
        allow(StripeService::Charge).to receive(:update)
        allow(StripeService::PaymentIntent).to receive(:retrieve) do |args|
          Stripe::PaymentIntent.construct_from(
            id: args[:id], object: "payment_intent", status: "succeeded", amount: 10_00, amount_received: 10_00,
            client_secret: "#{args[:id]}_secret",
            charges: { data: [{ id: "ch_test", refunded: false }] },
            latest_charge: {
              id: "ch_test", object: "charge",
              balance_transaction: { id: "txn_test", object: "balance_transaction", available_on: 2.days.from_now.to_i, net: 9_41, fee: 59 }
            }
          )
        end
      end

      it "creates one donation when the same invoice is delivered twice" do
        post_webhook(invoice_paid("evt_1"))
        post_webhook(invoice_paid("evt_2"))

        expect(response).to have_http_status(:no_content)
        expect(recurring_donation.donations.count).to eq(1)
        expect(fronted_cents).to eq(10_00)
      end

      it "creates a donation for each invoice" do
        post_webhook(invoice_paid("evt_1"))
        post_webhook(invoice_paid("evt_2", payment_intent: "pi_test_2"))

        expect(recurring_donation.donations.count).to eq(2)
        expect(fronted_cents).to eq(20_00)
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
