# frozen_string_literal: true

require "rails_helper"

RSpec.describe "minting a token copies an application's resource grants" do
  it "creates matching ResourceGrant rows on the issued token" do
    user = create(:user)

    application = Doorkeeper::Application.create!(
      name: "Test App",
      redirect_uri: "https://example.com/callback",
      scopes: "restricted comments:read",
      confidential: true,
    )
    application.resource_grants.create!(resource_type: "comments", access_level: "read", scope_root_type: "Event", scope_root_id: 42)
    application.resource_grants.create!(resource_type: "receipts", access_level: "write")

    # Redeeming a code via /token only needs client credentials, not a login
    # session - so we can skip the /authorize step (which does need one) and
    # just create the grant it would have produced.
    grant = Doorkeeper::AccessGrant.create!(
      application:,
      resource_owner_id: user.id,
      redirect_uri: application.redirect_uri,
      expires_in: 10.minutes,
      scopes: "restricted comments:read",
    )

    post "/api/v4/oauth/token", params: {
      grant_type: "authorization_code",
      code: grant.plaintext_token,
      client_id: application.uid,
      client_secret: application.plaintext_secret,
      redirect_uri: application.redirect_uri,
    }

    expect(response).to have_http_status(:ok), response.body
    token_string = response.parsed_body["access_token"]
    token = ApiToken.find_by(token: token_string)

    expect(token).to be_present
    expect(token.resource_grants.count).to eq(2)
    expect(token.resource_grants.pluck(:resource_type)).to contain_exactly("comments", "receipts")
  end
end
