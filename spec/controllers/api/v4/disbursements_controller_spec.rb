# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::V4::DisbursementsController do
  render_views

  describe "#show" do
    let(:source_event) { create(:event) }
    let(:destination_event) { create(:event) }
    let(:disbursement) { create(:disbursement, source_event:, event: destination_event) }

    def authenticate(user, scopes: nil)
      token = create(:api_token, user:, scopes:)
      request.headers["Authorization"] = "Bearer #{token.token}"
    end

    it "returns the transfer to a member of the sending organization" do
      user = create(:user)
      create(:organizer_position, user:, event: source_event)
      authenticate(user)

      get :show, params: { id: disbursement.public_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include("id" => disbursement.public_id, "object" => "disbursement")
    end

    it "returns the transfer to a member of the receiving organization" do
      user = create(:user)
      create(:organizer_position, user:, event: destination_event)
      authenticate(user)

      get :show, params: { id: disbursement.public_id }, as: :json

      expect(response).to have_http_status(:ok)
    end

    it "doesn't return the transfer to an unrelated user" do
      authenticate(create(:user))

      get :show, params: { id: disbursement.public_id }, as: :json

      expect(response).to have_http_status(:forbidden)
    end

    it "doesn't allow lookups by internal ID for non-admins" do
      user = create(:user)
      create(:organizer_position, user:, event: source_event)
      authenticate(user)

      get :show, params: { id: disbursement.id }, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it "allows lookups by internal ID for admins" do
      authenticate(create(:user, :make_admin), scopes: "admin:read")

      get :show, params: { id: disbursement.id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include("id" => disbursement.public_id)
    end
  end
end
