# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::V4::CommentsController do
  # Comments are the one resource with limited admin scopes: `admin:comments:read` /
  # `admin:comments:write` grant admin access to comments (and nothing else in the API).
  describe "#index" do
    render_views

    let(:hcb_code) { create(:hcb_code) }
    let!(:comment)       { create(:comment, commentable: hcb_code) }
    let!(:admin_comment) { create(:comment, commentable: hcb_code, admin_only: true) }

    def get_index(viewer:, scopes:)
      token = create(:api_token, user: viewer, scopes:)
      request.headers["Authorization"] = "Bearer #{token.token}"
      get(:index, params: { transaction_id: hcb_code.public_id }, as: :json)
    end

    it "returns every comment for an admin whose token carries admin:comments:read" do
      get_index(viewer: create(:user, access_level: :admin), scopes: "admin:comments:read")

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.map { |c| c["id"] }).to contain_exactly(comment.public_id, admin_comment.public_id)
    end

    it "returns 403 when the admin's token carries no admin scope" do
      get_index(viewer: create(:user, access_level: :admin), scopes: "")

      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 when the token only carries admin:comments:write" do
      get_index(viewer: create(:user, access_level: :admin), scopes: "admin:comments:write")

      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 for a non-admin user even when the token carries admin:comments:read" do
      get_index(viewer: create(:user), scopes: "admin:comments:read")

      expect(response).to have_http_status(:forbidden)
    end

    it "still works with the blanket admin:read scope" do
      get_index(viewer: create(:user, access_level: :admin), scopes: "admin:read")

      expect(response).to have_http_status(:ok)
    end
  end

  describe "#create" do
    let(:hcb_code) { create(:hcb_code) }

    def post_admin_comment(viewer:, scopes:)
      token = create(:api_token, user: viewer, scopes:)
      request.headers["Authorization"] = "Bearer #{token.token}"
      post(:create, params: { transaction_id: hcb_code.public_id, content: "hi", admin_only: true }, as: :json)
    end

    it "creates an admin-only comment when the token carries admin:comments:read and admin:comments:write" do
      post_admin_comment(viewer: create(:user, access_level: :admin), scopes: "admin:comments:read admin:comments:write")

      expect(response).to have_http_status(:created)
      expect(hcb_code.comments.last).to be_admin_only
    end

    it "returns 403 when the token only carries admin:comments:read" do
      post_admin_comment(viewer: create(:user, access_level: :admin), scopes: "admin:comments:read")

      expect(response).to have_http_status(:forbidden)
      expect(hcb_code.comments).to be_empty
    end

    it "still works with the blanket admin:read and admin:write scopes" do
      post_admin_comment(viewer: create(:user, access_level: :admin), scopes: "admin:read admin:write")

      expect(response).to have_http_status(:created)
    end
  end
end
