# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::V4::DonationsController do
  include DonationSupport

  render_views

  describe "#index" do
    it "paginates newest first and follows the after cursor" do
      stub_donation_payment_intent_creation
      allow(StripeService::PaymentIntent).to receive(:retrieve).and_return(Stripe::PaymentIntent.construct_from(id: "pi_stub", payment_method: nil))

      user  = create(:user)
      event = create(:event)
      create(:organizer_position, user:, event:)

      token = create(:api_token, user:)
      request.headers["Authorization"] = "Bearer #{token.token}"

      donations = 3.times.map do |i|
        create(:donation, event:, aasm_state: "deposited", created_at: i.days.ago)
      end
      newest, middle, oldest = donations

      get :index, params: { event_id: event.public_id, limit: 2 }, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["total_count"]).to eq(3)
      expect(response.parsed_body["has_more"]).to be true
      expect(response.parsed_body["data"].map { |d| d["id"] }).to eq([newest.public_id, middle.public_id])

      get :index, params: { event_id: event.public_id, limit: 2, after: middle.public_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["has_more"]).to be false
      expect(response.parsed_body["data"].map { |d| d["id"] }).to eq([oldest.public_id])
    end

    it "rejects an unknown after cursor" do
      user  = create(:user)
      event = create(:event)
      create(:organizer_position, user:, event:)

      token = create(:api_token, user:)
      request.headers["Authorization"] = "Bearer #{token.token}"

      get :index, params: { event_id: event.public_id, after: "don_nonexistent" }, as: :json

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body["error"]).to eq("invalid_operation")
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
