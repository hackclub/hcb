# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::V5::OrganizerPositionsController do
  render_views

  before do
    allow_any_instance_of(UsersHelper).to receive(:profile_picture_for).and_return("https://gravatar.com/avatar/stubbed")
  end

  let!(:transparent) { create(:event, :with_positive_balance, is_public: true) }
  let!(:private_org) { create(:event, :with_positive_balance, is_public: false) }

  # v3 publishes a transparent organization's user list, so the roster is
  # public there — but each organizer's own fields stay UserPolicy's call.
  it "lists a transparent organization's roster anonymously" do
    create(:organizer_position, user: create(:user, full_name: "Ada Lovelace"), event: transparent, role: :manager)

    get :index, params: {}, as: :json

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["data"].size).to eq(1)
  end

  it "degrades an organizer's name for an anonymous viewer" do
    create(:organizer_position, user: create(:user, full_name: "Ada Lovelace"), event: transparent, role: :manager)

    get :index, params: { expand: "user" }, as: :json

    expect(response.parsed_body["data"].first.dig("user", "name")).to eq("Ada L")
    expect(response.body).not_to include("Ada Lovelace")
  end

  it "does not list a private organization's roster anonymously" do
    create(:organizer_position, user: create(:user), event: private_org, role: :manager)

    get :index, params: {}, as: :json

    expect(response.parsed_body["data"]).to be_empty
  end

end
