# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::V4::AchTransfersController do
  render_views

  describe "#show" do
    let(:event) do
      event = create(:event)
      create(:canonical_pending_transaction, amount_cents: 1000, event:, fronted: true)
      event
    end
    let(:ach_transfer) { create(:ach_transfer, event:) }

    def authenticate(user, scopes: nil)
      token = create(:api_token, user:, scopes:)
      request.headers["Authorization"] = "Bearer #{token.token}"
    end

    it "returns the transfer by public ID" do
      user = create(:user)
      create(:organizer_position, user:, event:)
      authenticate(user)

      get :show, params: { id: ach_transfer.public_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include("id" => ach_transfer.public_id, "object" => "ach_transfer")
    end

    it "doesn't return the transfer to an unrelated user" do
      authenticate(create(:user))

      get :show, params: { id: ach_transfer.public_id }, as: :json

      expect(response).to have_http_status(:forbidden)
    end

    it "doesn't allow lookups by internal ID for non-admins" do
      user = create(:user)
      create(:organizer_position, user:, event:)
      authenticate(user)

      get :show, params: { id: ach_transfer.id }, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it "allows lookups by internal ID for admins" do
      authenticate(create(:user, :make_admin), scopes: "admin:read")

      get :show, params: { id: ach_transfer.id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include("id" => ach_transfer.public_id)
    end

    it "404s on an unknown ID for admins" do
      authenticate(create(:user, :make_admin), scopes: "admin:read")

      get :show, params: { id: "ach_nonexistent" }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end
end
