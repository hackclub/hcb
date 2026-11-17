# frozen_string_literal: true

require "rails_helper"

RSpec.describe "API v4 sponsors", type: :request do
  before do
    allow_any_instance_of(Sponsor).to receive(:create_stripe_customer)
  end

  let(:event) { create(:event) }

  def create_sponsor(user)
    token = create(:api_token, user:)
    post "/api/v4/sponsors",
         params: {
           event_id: event.public_id,
           sponsor: {
             name: "Orpheus Inc.",
             contact_email: "orpheus@example.com",
             address_line1: "15 Falls Rd.",
             address_city: "Shelburne",
             address_state: "VT",
             address_postal_code: "05482",
             address_country: "US",
           }
         },
         headers: { "Authorization" => "Bearer #{token.token}" }
  end

  describe "POST /api/v4/sponsors" do
    it "lets a member of the organization create a sponsor" do
      user = create(:user)
      create(:organizer_position, event:, user:, role: :member)

      expect { create_sponsor(user) }.to change(event.sponsors, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(response.parsed_body["name"]).to eq("Orpheus Inc.")
    end

    it "forbids a reader of the organization" do
      user = create(:user)
      create(:organizer_position, event:, user:, role: :reader)

      expect { create_sponsor(user) }.not_to change(Sponsor, :count)

      expect(response).to have_http_status(:forbidden)
    end

    it "forbids a user outside the organization" do
      expect { create_sponsor(create(:user)) }.not_to change(Sponsor, :count)

      expect(response).to have_http_status(:forbidden)
    end
  end
end
