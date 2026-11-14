# frozen_string_literal: true

require "rails_helper"

RSpec.describe "OAuth applications", type: :request do
  let(:admin) { create(:user, :make_admin) }
  let(:poc) { create(:user, email: "poc@hackclub.com") }

  before do
    admin_session = create(:user_session, user: admin, verified: true, expiration_at: 1.hour.from_now)

    allow_any_instance_of(SessionsHelper)
      .to receive(:find_current_session)
      .and_return(admin_session)
  end

  def create_application(owner_email:)
    post "/api/v4/oauth/applications", params: {
      doorkeeper_application: { name: "Test App", redirect_uri: "https://example.com/callback", owner_email: }
    }
  end

  it "assigns the point of contact by email" do
    create_application(owner_email: poc.email)

    expect(Doorkeeper::Application.sole.owner).to eq(poc)
  end

  it "keeps the point of contact when updating without an email" do
    application = Doorkeeper::Application.create!(name: "Test App", redirect_uri: "https://example.com/callback", owner: poc)

    patch "/api/v4/oauth/applications/#{application.id}", params: { doorkeeper_application: { name: "Renamed" } }

    expect(application.reload).to have_attributes(name: "Renamed", owner: poc)
  end

  it "shows the point of contact" do
    application = Doorkeeper::Application.create!(name: "Test App", redirect_uri: "https://example.com/callback", owner: poc)

    get "/api/v4/oauth/applications/#{application.id}"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(poc.email)
  end

  it "lists the point of contact" do
    Doorkeeper::Application.create!(name: "Test App", redirect_uri: "https://example.com/callback", owner: poc)

    get "/api/v4/oauth/applications"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(poc.email)
  end
end
