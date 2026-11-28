# frozen_string_literal: true

require "rails_helper"

RSpec.describe "GET /api/v4/user/organizations", type: :request do
  let(:user) { create(:user) }
  let(:token) { create(:api_token, user:, scopes: "organizations:read") }

  it "leaves out organizations the user is locked out of for not enabling two-factor authentication" do
    locked_out = create(:organizer_position, user:, event: create(:event, name: "Locked Out Org")).event
    open_event = create(:organizer_position, user:, event: create(:event, name: "Open Org")).event
    require_two_factor_authentication!(locked_out, at: 8.days.ago)

    get "/api/v4/user/organizations", headers: { "Authorization" => "Bearer #{token.token}" }

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.map { |organization| organization["name"] }).to eq([open_event.name])
  end
end
