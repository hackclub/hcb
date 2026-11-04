# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Doorkeeper authorizations while impersonating", type: :request do
  let(:admin) { create(:user, :make_admin) }
  let(:user) { create(:user) }
  let(:application) do
    Doorkeeper::Application.create!(name: "Test App", redirect_uri: "https://example.com/callback", scopes: "read")
  end

  before do
    impersonation_session = create(:user_session, user:, impersonated_by: admin, expiration_at: 1.hour.from_now)
    allow_any_instance_of(SessionsHelper).to receive(:find_current_session).and_return(impersonation_session)
  end

  it "does not grant an authorization code" do
    expect {
      post "/api/v4/oauth/authorize", params: {
        client_id: application.uid,
        redirect_uri: application.redirect_uri,
        response_type: "code",
        scope: "read",
      }
    }.not_to change(Doorkeeper::AccessGrant, :count)

    expect(response).to redirect_to(root_path)
  end

  it "does not authorize a device" do
    device_grant = Doorkeeper::DeviceAuthorizationGrant::DeviceGrant.create!(
      application:,
      expires_in: 300,
      scopes: "read",
      user_code: "ABCD1234",
    )

    post "/api/v4/oauth/device", params: { user_code: "ABCD1234" }

    expect(response).to redirect_to(root_path)
    expect(device_grant.reload.resource_owner_id).to be_nil
  end
end
