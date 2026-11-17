# frozen_string_literal: true

require "rails_helper"

RSpec.describe "API v4 wires", type: :request do
  before do
    stub_request(:get, /api\.column\.com\/institutions\/.*/)
      .to_return(status: 200, body: '{"country_code": "DE"}', headers: { "Content-Type" => "application/json" })
  end

  let(:event) { create(:event, :with_positive_balance) }
  let(:wire) { create(:wire, event:) }

  def get_wire(user)
    token = create(:api_token, user:)
    get "/api/v4/wires/#{wire.public_id}", headers: { "Authorization" => "Bearer #{token.token}" }
  end

  describe "GET /api/v4/wires/:id" do
    it "returns the wire to a reader of its organization" do
      user = create(:user)
      create(:organizer_position, event:, user:, role: :reader)

      get_wire(user)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["id"]).to eq(wire.public_id)
    end

    it "forbids a user outside a transparent organization" do
      event.update!(is_public: true)

      get_wire(create(:user))

      expect(response).to have_http_status(:forbidden)
    end
  end
end
