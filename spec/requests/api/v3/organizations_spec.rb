# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V3 organizations", type: :request do
  let(:event) { create(:event, is_public: true) }

  describe "GET /organizations" do
    it "rejects per_page above the cap" do
      get "/api/v3/organizations", params: { per_page: 101 }

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body).to include("error" => "per_page must be less than or equal 100")
    end

    it "allows per_page at the cap" do
      get "/api/v3/organizations", params: { per_page: 100 }

      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /organizations/:id/transactions" do
    before do
      ct = create(:canonical_transaction, amount_cents: -1234, memo: "Test transaction", date: Date.current)
      create(:canonical_event_mapping, event:, canonical_transaction: ct)
    end

    it "appends the .json format suffix to hrefs" do
      get "/api/v3/organizations/#{event.slug}/transactions"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.first["href"]).to end_with(".json")
    end
  end
end
