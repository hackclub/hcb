# frozen_string_literal: true

require "rails_helper"

RSpec.describe "OAuth tokens of locked users", type: :request do
  let(:user) { create(:user) }
  let(:application) do
    Doorkeeper::Application.create!(name: "Test App", redirect_uri: "https://example.com/callback", scopes: "read")
  end
  # Access tokens expire after two hours, so by the time staff lock an account
  # most of its OAuth tokens look like this: expired, unrevoked, and still
  # holding a refresh token.
  let!(:expired_token) do
    create(:api_token, user:, application:, scopes: "read", use_refresh_token: true, expires_in: 1, created_at: 3.hours.ago)
  end

  def refresh(token)
    post "/api/v4/oauth/token", params: {
      grant_type: "refresh_token",
      refresh_token: token.refresh_token,
      client_id: application.uid,
      client_secret: application.secret,
    }
  end

  it "refreshes an expired token for an unlocked user" do
    expect { refresh(expired_token) }.to change(ApiToken, :count).by(1)

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to include("access_token", "refresh_token")
  end

  context "when the user is locked" do
    before { user.lock! }

    it "does not refresh the expired token" do
      expect { refresh(expired_token) }.not_to change(ApiToken, :count)

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body["error"]).to eq("invalid_grant")
    end

    it "does not refresh a token that outlived the lock" do
      # Expired tokens of users locked before `lock!` revoked them.
      expired_token.update_column(:revoked_at, nil)

      expect { refresh(expired_token) }.not_to change(ApiToken, :count)

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body["error"]).to eq("invalid_grant")
    end

    it "rejects access tokens issued before the lock" do
      live_token = create(:api_token, user:, application:, scopes: "read", use_refresh_token: true)
      user.lock!

      get "/api/v4/user", headers: { "Authorization" => "Bearer #{live_token.token}" }

      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body["error"]).to eq("invalid_auth")
    end
  end
end
