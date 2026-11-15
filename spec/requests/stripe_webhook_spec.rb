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

    context "with a setup_intent.succeeded event for a recurring donation" do
      let(:recurring_donation) do
        RecurringDonation.create!(
          event: create(:event),
          name: "Jane Smith",
          email: "jane@example.com",
          amount: 10_00,
          stripe_subscription_id: "sub_test",
          stripe_customer_id: "cus_test"
        )
      end
      let(:payload) do
        {
          id: "evt_test",
          object: "event",
          type: "setup_intent.succeeded",
          data: {
            object: {
              id: "seti_test",
              object: "setup_intent",
              payment_method: "pm_test",
              metadata: { recurring_donation_id: recurring_donation.id.to_s }
            }
          }
        }.to_json
      end

      def post_webhook
        post "/stripe/webhook",
             params: payload,
             headers: { "Stripe-Signature" => stripe_signature(payload), "Content-Type" => "application/json" }
      end

      def build_subscription(status:, last4: "1111")
        Stripe::Subscription.construct_from(
          id: "sub_test",
          status:,
          customer: "cus_test",
          current_period_end: 1.month.from_now.to_i,
          canceled_at: nil,
          latest_invoice: nil,
          default_payment_method: { id: "pm_default", object: "payment_method", card: { last4: } }
        )
      end

      %w[canceled incomplete_expired].each do |status|
        context "when the subscription is #{status}" do
          before do
            allow(StripeService::Subscription).to receive(:retrieve).and_return(build_subscription(status:))
            allow(StripeService::Subscription).to receive(:update)
          end

          it "responds successfully without changing the subscription's payment method" do
            post_webhook

            expect(response).to have_http_status(:no_content)
            expect(StripeService::Subscription).not_to have_received(:update)
          end

          it "doesn't tell the donor their payment method changed" do
            expect { post_webhook }.not_to have_enqueued_mail(RecurringDonationMailer, :payment_method_changed)
          end
        end
      end

      %w[active past_due].each do |status|
        context "when the subscription is #{status}" do
          before do
            subscription = build_subscription(status:, last4: "1111")
            allow(StripeService::Subscription).to receive(:retrieve) { subscription }
            allow(StripeService::Subscription).to receive(:update) do
              subscription = build_subscription(status:, last4: "4242")
            end
          end

          it "makes the payment method the subscription's default and tells the donor" do
            expect { post_webhook }.to have_enqueued_mail(RecurringDonationMailer, :payment_method_changed)

            expect(response).to have_http_status(:no_content)
            expect(StripeService::Subscription).to have_received(:update).with("sub_test", default_payment_method: "pm_test")
          end

          it "records the new card on the donation" do
            post_webhook

            expect(recurring_donation.reload.last4).to eq("4242")
          end
        end
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
