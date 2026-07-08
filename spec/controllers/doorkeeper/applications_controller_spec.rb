# frozen_string_literal: true

require "rails_helper"

RSpec.describe Doorkeeper::ApplicationsController do
  include SessionSupport
  render_views

  before do
    admin = create(:user, :make_admin)
    create_session(admin, verified: true)
  end

  describe "#new" do
    it "renders the scope catalog as checkboxes instead of a raw text field" do
      get :new

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Read organizations")
      expect(response.body).to include('data-scope="organizations:read"')
      expect(response.body).not_to include('type="text" name="doorkeeper_application[scopes]"')
    end
  end

  describe "#edit" do
    it "pre-checks scopes the application already has" do
      application = OauthApplication.create!(name: "Test App", redirect_uri: "https://example.com/callback", scopes: "restricted receipts:read some_future_scope")

      get :edit, params: { id: application.id }

      expect(response).to have_http_status(:ok)
      expect(response.body).to match(/data-scope="restricted"[^>]*checked/)
      expect(response.body).to match(/data-scope="receipts:read"[^>]*checked/)
      expect(response.body).to include("some_future_scope")
    end
  end
end
