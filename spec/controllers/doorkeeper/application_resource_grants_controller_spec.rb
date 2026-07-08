# frozen_string_literal: true

require "rails_helper"

RSpec.describe Doorkeeper::ApplicationResourceGrantsController do
  include SessionSupport

  let(:application) { Doorkeeper::Application.create!(name: "Test App", redirect_uri: "https://example.com/callback", scopes: "restricted comments:read") }

  describe "#create" do
    it "is forbidden for a non-admin" do
      create_session(create(:user), verified: true)

      expect do
        post :create, params: { application_id: application.id, resource_grant: { resource_type: "comments", access_level: "read", scope_root_type: "Event", scope_root_id: 42 } }
      end.not_to change(ResourceGrant, :count)
    end

    context "as an admin" do
      before { create_session(create(:user, :make_admin), verified: true) }

      it "creates a scope-root grant" do
        expect do
          post :create, params: { application_id: application.id, resource_grant: { resource_type: "comments", access_level: "read", scope_root_type: "Event", scope_root_id: 42 } }
        end.to change { application.resource_grants.count }.by(1)

        expect(response).to redirect_to(edit_oauth_application_path(application))
        grant = application.resource_grants.last
        expect(grant.scope_root_type).to eq("Event")
        expect(grant.scope_root_id).to eq(42)
      end

      it "creates a whole-type grant when no scope root is given" do
        post :create, params: { application_id: application.id, resource_grant: { resource_type: "receipts", access_level: "write" } }

        grant = application.resource_grants.last
        expect(grant.scope_root_type).to be_nil
      end

      it "rejects an invalid combination and redirects with an error" do
        expect do
          post :create, params: { application_id: application.id, resource_grant: { resource_type: "comments", access_level: "read", scope_root_type: "Event" } }
        end.not_to change(ResourceGrant, :count)

        expect(response).to redirect_to(edit_oauth_application_path(application))
        expect(flash[:alert]).to be_present
      end
    end
  end

  describe "#destroy" do
    it "removes the grant" do
      create_session(create(:user, :make_admin), verified: true)
      grant = application.resource_grants.create!(resource_type: "comments", access_level: "read", scope_root_type: "Event", scope_root_id: 1)

      expect do
        delete :destroy, params: { application_id: application.id, id: grant.id }
      end.to change { application.resource_grants.count }.by(-1)
    end
  end
end
