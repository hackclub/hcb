# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::V4::DonationsController do
  render_views

  describe "#create" do
    it "creates a donation" do
      user  = create(:user)
      event = create(:event)
      create(:organizer_position, user:, event:)

      token = create(:api_token, user:)
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
