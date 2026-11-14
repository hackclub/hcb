# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Revoking an OAuth application's tokens", type: :request do
  let(:application) { Doorkeeper::Application.create!(name: "Test App", redirect_uri: "https://example.com/callback", scopes: "read") }
  let(:other_application) { Doorkeeper::Application.create!(name: "Other App", redirect_uri: "https://example.com/other", scopes: "read") }

  def sign_in(user)
    user_session = create(:user_session, user:, verified: true, expiration_at: 1.hour.from_now)
    allow_any_instance_of(SessionsHelper).to receive(:find_current_session).and_return(user_session)
  end

  context "as an admin" do
    before { sign_in(create(:user, :make_admin)) }

    it "shows the button on the application page" do
      get oauth_application_path(application)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Revoke all tokens")
    end

    it "revokes every token, including expired ones that still hold a refresh token" do
      live = create(:api_token, user: create(:user), application:, use_refresh_token: true)
      expired = create(:api_token, user: create(:user), application:, use_refresh_token: true, expires_in: 1, created_at: 3.hours.ago)

      post revoke_tokens_oauth_application_path(application)

      expect([live, expired].each(&:reload)).to all(be_revoked)
      expect(response).to redirect_to(oauth_application_path(application))
      follow_redirect!
      expect(response.body).to include("Revoked 2 tokens.")
    end

    it "revokes outstanding authorization codes and device codes" do
      user = create(:user)
      grant = Doorkeeper::AccessGrant.create!(application:, resource_owner_id: user.id, expires_in: 600, redirect_uri: application.redirect_uri, scopes: "read")
      pending_device_grant = Doorkeeper::DeviceAuthorizationGrant::DeviceGrant.create!(application:, expires_in: 300, scopes: "read", user_code: "PEND1234")
      approved_device_grant = Doorkeeper::DeviceAuthorizationGrant::DeviceGrant.create!(application:, expires_in: 300, scopes: "read", resource_owner_id: user.id)

      post revoke_tokens_oauth_application_path(application)

      expect(grant.reload).to be_revoked
      expect(Doorkeeper::DeviceAuthorizationGrant::DeviceGrant.where(id: [pending_device_grant.id, approved_device_grant.id])).to be_empty
    end

    it "leaves other applications' tokens alone" do
      user = create(:user)
      other_token = create(:api_token, user:, application: other_application, use_refresh_token: true)
      other_grant = Doorkeeper::AccessGrant.create!(application: other_application, resource_owner_id: user.id, expires_in: 600, redirect_uri: other_application.redirect_uri, scopes: "read")
      other_device_grant = Doorkeeper::DeviceAuthorizationGrant::DeviceGrant.create!(application: other_application, expires_in: 300, scopes: "read", user_code: "OTHR1234")

      post revoke_tokens_oauth_application_path(application)

      expect(other_token.reload).not_to be_revoked
      expect(other_grant.reload).not_to be_revoked
      expect(Doorkeeper::DeviceAuthorizationGrant::DeviceGrant.exists?(other_device_grant.id)).to be(true)
    end
  end

  context "as an auditor" do
    before { sign_in(create(:user, :make_auditor)) }

    it "does not revoke anything" do
      token = create(:api_token, user: create(:user), application:, use_refresh_token: true)

      post revoke_tokens_oauth_application_path(application)

      expect(token.reload).not_to be_revoked
      expect(response).to redirect_to(root_path)
    end
  end
end
