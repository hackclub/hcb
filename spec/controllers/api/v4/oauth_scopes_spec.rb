# frozen_string_literal: true

require "rails_helper"

# Covers the granular OAuth scopes declared in config/api_scopes.rb: that they're actually
# requestable, that they're enforced on `restricted` tokens, and that tokens without `restricted`
# keep working exactly as before.
RSpec.describe "v4 OAuth scopes" do
  let(:configured_scopes) { Doorkeeper.config.optional_scopes.to_a.map(&:to_s) }

  describe "configuration" do
    # Every scope a controller gates on has to be requestable, or an app can never obtain a token
    # that satisfies the gate — the request fails with `invalid_scope` at authorization time.
    let(:declared_scopes) do
      Rails.application.eager_load!

      Api::V4::ApplicationController.descendants.flat_map { |controller|
        (controller.instance_variable_get(:@oauth_requirements) || {}).values
      }.flatten.uniq
    end

    it "makes every scope used by a controller requestable" do
      expect(declared_scopes - configured_scopes).to be_empty
    end

    it "has no granular scope that no controller actually uses" do
      expect(ApiScopes::GRANULAR.keys - declared_scopes).to be_empty
    end

    it "allows apps to request the restricted marker scope" do
      expect(configured_scopes).to include(ApiScopes::RESTRICTED)
    end

    it "keeps the pre-existing broad scopes requestable" do
      expect(configured_scopes).to include("read", "write", "admin:read", "admin:write")
    end
  end

  # End-to-end through the device grant, which is how CLI/MCP-style integrations sign in: an app
  # asks for granular scopes, the user approves, and the token it gets back is held to exactly
  # those scopes.
  describe "the device authorization grant", type: :request do
    let(:user) { create(:user) }
    let(:application) do
      Doorkeeper::Application.create!(
        name: "Receipt Matcher",
        # Required by the model even for device-flow apps, which never redirect anywhere.
        redirect_uri: "https://example.com/callback",
        confidential: false,
        scopes: "restricted receipts:read receipts:write"
      )
    end

    # Stands in for the user approving at /api/v4/oauth/device, which is all that controller does.
    def approve_latest_grant!
      grant = Doorkeeper::DeviceAuthorizationGrant.configuration.device_grant_model.last
      grant.update!(user_code: nil, resource_owner_id: user.id)
    end

    def sign_in_via_device_flow(scope:)
      post "/api/v4/oauth/authorize_device", params: { client_id: application.uid, scope: }
      expect(response).to have_http_status(:ok)
      device_code = response.parsed_body.fetch("device_code")

      approve_latest_grant!

      post "/api/v4/oauth/token", params: {
        grant_type: "urn:ietf:params:oauth:grant-type:device_code",
        device_code:,
        client_id: application.uid
      }
      response.parsed_body
    end

    it "issues a token carrying the granular scopes that were asked for" do
      token = sign_in_via_device_flow(scope: "restricted receipts:read receipts:write")

      expect(token["scope"]).to eq("restricted receipts:read receipts:write")
      expect(token["access_token"]).to be_present
    end

    it "produces a token that is actually held to those scopes" do
      token = sign_in_via_device_flow(scope: "restricted receipts:read")

      # receipts:read is granted, so the receipt bin is reachable...
      get "/api/v4/receipts", headers: { "Authorization" => "Bearer #{token['access_token']}" }
      expect(response).to have_http_status(:ok)

      # ...but nothing else the app didn't ask for is.
      get "/api/v4/user/transactions/missing_receipt",
          headers: { "Authorization" => "Bearer #{token['access_token']}" }
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe Api::V4::ReceiptsController do
    let(:user) { create(:user) }

    def get_receipt_bin(scopes:)
      token = create(:api_token, user:, scopes:)
      request.headers["Authorization"] = "Bearer #{token.token}"
      get(:index, as: :json)
    end

    context "with a restricted token" do
      it "allows the request when the token carries receipts:read" do
        get_receipt_bin(scopes: "restricted receipts:read")

        expect(response).to have_http_status(:ok)
      end

      it "returns 403 when the token is missing receipts:read" do
        get_receipt_bin(scopes: "restricted ledgers:read")

        expect(response).to have_http_status(:forbidden)
        expect(response.parsed_body).to eq("error" => "not_authorized")
      end

      it "returns 403 when the token carries no granular scopes at all" do
        get_receipt_bin(scopes: "restricted")

        expect(response).to have_http_status(:forbidden)
      end
    end

    # The whole point of gating enforcement behind `restricted` is that existing integrations,
    # which request `read write` or nothing at all, are unaffected.
    context "without the restricted scope" do
      it "allows a token carrying no scopes" do
        get_receipt_bin(scopes: "")

        expect(response).to have_http_status(:ok)
      end

      it "allows a token carrying only read/write" do
        get_receipt_bin(scopes: "read write")

        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe Api::V4::TransactionsController do
    let(:user) { create(:user) }

    def get_missing_receipt(scopes:)
      token = create(:api_token, user:, scopes:)
      request.headers["Authorization"] = "Bearer #{token.token}"
      get(:missing_receipt, as: :json)
    end

    it "allows the request when the token carries ledgers:read" do
      get_missing_receipt(scopes: "restricted ledgers:read")

      # 204 rather than 200 here: controller specs don't render the jbuilder view.
      expect(response).to be_successful
    end

    it "returns 403 when the token only carries receipts:write" do
      get_missing_receipt(scopes: "restricted receipts:write")

      expect(response).to have_http_status(:forbidden)
    end
  end
end
