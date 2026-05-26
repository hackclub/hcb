# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::V4::DonationsController do
  include DonationSupport

  render_views

  describe "#payment_intent" do
    before { stub_donation_payment_intent_creation }

    it "returns the payment intent id and client secret for an organizer's donation" do
      user = create(:user)
      event = create(:event)
      create(:organizer_position, user:, event:)

      donation = create(:donation, event:, collected_by: user, in_person: true)
      oauth_application = Doorkeeper::Application.create!(
        name: "Trusted POS",
        redirect_uri: "https://example.com/callback",
        scopes: "",
        confidential: true,
        trusted: true
      )
      token = create(:api_token, user:, application_id: oauth_application.id)
      request.headers["Authorization"] = "Bearer #{token.token}"

      post :payment_intent, params: { event_id: event.public_id, id: donation.public_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq(
        {
          "payment_intent_id" => donation.stripe_payment_intent_id,
          "client_secret"     => donation.stripe_client_secret
        }
      )
    end
  end

  describe "#create" do
    before do
      stub_donation_payment_intent_creation
      allow(StripeService::PaymentIntent).to receive(:retrieve).and_return(Stripe::PaymentIntent.construct_from(id: "pi_stub", payment_method: nil))
    end

    it "creates a donation" do
      user  = create(:user)
      event = create(:event)
      create(:organizer_position, user:, event:)

      trusted_app = Doorkeeper::Application.create!(name: "Trusted App", redirect_uri: "https://hcb.hackclub.com", trusted: true)
      token = create(:api_token, user:, application: trusted_app)
      request.headers["Authorization"] = "Bearer #{token.token}"

      message = "Thanks for the great work — keep it up!"

      post :create, params: {
        event_id: event.public_id,
        amount_cents: 900,
        name: "Donor",
        email: "donor@example.com",
        message:,
        tax_deductible: false,
      }, as: :json

      expect(response).to have_http_status(:created)
      donation = event.donations.sole

      expect(response.parsed_body).to include(
        {
          "id"         => donation.public_id,
          "object"     => "donation",
          "recurring"  => false,
          "donor"      => {
            "name"  => "Donor",
            "email" => "donor@example.com",
          },
          "message"    => message,
          "donated_at" => donation.donated_at.iso8601(3),
          "refunded"   => false,
          "deposited"  => false,
          "in_transit" => false,
          "created_at" => donation.created_at.iso8601(3),
        }
      )
    end
  end
end
