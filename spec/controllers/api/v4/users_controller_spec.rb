# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::V4::UsersController do
  let(:admin_read_only_scopes) { "restricted read admin:read organizations:read ledgers:read receipts:read user_lookup event_followers" }

  def authenticate(user:, scopes:)
    token = create(:api_token, user:, scopes:)
    request.headers["Authorization"] = "Bearer #{token.token}"
  end

  # `#show` is gated by `require_admin_scope!(:read)`.
  describe "#show" do
    let(:target) { create(:user, full_name: "Target User") }

    def get_show(viewer:, scopes:)
      authenticate(user: viewer, scopes:)
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

    it "allows a restricted read-only admin token" do
      get_show(viewer: create(:user, access_level: :admin), scopes: admin_read_only_scopes)

      expect(response).to have_http_status(:ok)
    end
  end

  describe "#me" do
    it "allows a restricted token with the coarse read scope" do
      authenticate(user: create(:user), scopes: "restricted read")

      get(:me, as: :json)

      expect(response).to have_http_status(:ok)
    end
  end

  describe "#revoke" do
    it "rejects restricted read-only tokens because revoke is a write action" do
      authenticate(user: create(:user), scopes: admin_read_only_scopes)

      post(:revoke, as: :json)

      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body).to eq("error" => "not_authorized")
    end
  end
end
