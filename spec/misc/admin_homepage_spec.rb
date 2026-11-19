# frozen_string_literal: true

require "rails_helper"

RSpec.describe AdminController, type: :controller do
  include SessionSupport
  render_views

  before { create_session(create(:user, :make_admin), verified: true) }

  describe "#index" do
    it "is served at /admin instead of redirecting to the organizations table" do
      expect(admin_index_path).to eq("/admin")

      get :index

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("HCB Admin")
    end

    it "links to itself from the sidebar" do
      get :index

      home = Nokogiri::HTML(response.body).at_css("a[href='/admin']")
      expect(home["aria-current"]).to eq("page")
    end
  end
end
