# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::V4::DonationsController do
  render_views

  describe "#create" do
    it "persists the message and echoes it back in the response" do
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
      expect(response.parsed_body["message"]).to eq(message)

      donation = Donation.find_by_public_id(response.parsed_body["id"])
      expect(donation.message).to eq(message)
    end
  end
end
