# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::V4::UsersController do
  # `#show` is gated by `require_admin_scope!(:read)`.
  describe "#show" do
    let(:target) { create(:user, full_name: "Target User") }

    def get_show(viewer:, scopes:)
      token = create(:api_token, user: viewer, scopes:)
      request.headers["Authorization"] = "Bearer #{token.token}"
      get(:show, params: { id: target.public_id }, as: :json)
    end

    it "returns 403 (not 401) when an admin's token lacks the admin:read scope" do
      get_show(viewer: create(:user, access_level: :admin), scopes: "")

      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body).to eq("error" => "not_authorized")
    end

    it "returns 403 for a non-admin user even when the token carries admin:read" do
      get_show(viewer: create(:user), scopes: "admin:read")

      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body).to eq("error" => "not_authorized")
    end

    it "allows an admin whose token carries admin:read" do
      get_show(viewer: create(:user, access_level: :admin), scopes: "admin:read")

      expect(response).to have_http_status(:ok)
    end
  end
end
