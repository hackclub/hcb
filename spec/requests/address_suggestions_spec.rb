# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Address suggestions", type: :request do
  let(:user) { create(:user) }

  context "when signed in" do
    before do
      user_session = create(:user_session, user:, expiration_at: 1.hour.from_now)
      allow_any_instance_of(SessionsHelper).to receive(:find_current_session).and_return(user_session)
    end

    it "returns the suggestions for the query and country as JSON" do
      stub_address_suggestions(letterman_drive_feature, with: ["1 Letterman", { params: hash_including(country: "us") }])

      get address_suggestions_path, params: { q: "1 Letterman", country: "US" }, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq([
                                           {
                                             "label"       => "1 Letterman Drive, San Francisco, California 94129, United States",
                                             "line1"       => "1 Letterman Drive",
                                             "city"        => "San Francisco",
                                             "state_name"  => "California",
                                             "state_code"  => "CA",
                                             "postal_code" => "94129",
                                             "country"     => "US",
                                           },
                                         ])
    end

    it "returns an empty list for a query that is too short to search" do
      stub_address_suggestions

      get address_suggestions_path, params: { q: "1" }, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq([])
      expect(Geocoder).not_to have_received(:search)
    end
  end

  context "when signed out" do
    it "redirects to the login page without searching" do
      stub_address_suggestions

      get address_suggestions_path, params: { q: "1 Letterman" }

      expect(response).to have_http_status(:redirect)
      expect(response.location).to include(auth_users_path)
      expect(Geocoder).not_to have_received(:search)
    end
  end
end
