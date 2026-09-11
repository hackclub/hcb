# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::V5::EventsController do
  render_views

  before do
    allow_any_instance_of(UsersHelper).to receive(:profile_picture_for).and_return("https://gravatar.com/avatar/stubbed")
  end

  let!(:transparent) { create(:event, :with_positive_balance, is_public: true, name: "Open Org") }
  let!(:private_org) { create(:event, :with_positive_balance, is_public: false, name: "Closed Org") }

  def authenticate_as(user)
    request.headers["Authorization"] = "Bearer #{create(:api_token, user:).token}"
  end

  # The v3 public tier: Api::Entities::Organization's fields, and nothing that
  # identifies the people or the banking details behind the organization.
  WITHHELD_FROM_PUBLIC = %w[account_number routing_number swift_bic_code total_spent_cents plan].freeze

  describe "#show" do
    it "serves a transparent organization without a token" do
      get :show, params: { id: transparent.public_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include("name" => "Open Org", "transparent" => true)
    end

    it "accepts a slug as well as a public id" do
      get :show, params: { id: transparent.slug }, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["id"]).to eq(transparent.public_id)
    end

    it "refuses a private organization to an anonymous caller" do
      get :show, params: { id: private_org.public_id }, as: :json

      expect(response).to have_http_status(:forbidden)
    end

    it "withholds banking and internal fields from the public tier" do
      get :show, params: { id: transparent.public_id, expand: "account_number,reporting,plan" }, as: :json

      expect(response.parsed_body).not_to include(*WITHHELD_FROM_PUBLIC)
    end

    it "adds banking and reporting fields for a manager" do
      user = create(:user)
      create(:organizer_position, user:, event: private_org, role: :manager)
      authenticate_as(user)

      get :show, params: { id: private_org.public_id, expand: "account_number,reporting" }, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.keys).to include("account_number", "routing_number", "total_spent_cents")
    end
  end

  describe "#index" do
    it "lists only transparent organizations anonymously" do
      get :index, params: {}, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["data"].map { |e| e["name"] }).to contain_exactly("Open Org")
    end

    it "adds the viewer's own organizations" do
      user = create(:user)
      create(:organizer_position, user:, event: private_org, role: :reader)
      authenticate_as(user)

      get :index, params: {}, as: :json

      expect(response.parsed_body["data"].map { |e| e["name"] }).to contain_exactly("Open Org", "Closed Org")
    end

    it "does not leak an unrelated private organization" do
      other = create(:event, :with_positive_balance, is_public: false, name: "Someone Else")
      user = create(:user)
      create(:organizer_position, user:, event: private_org, role: :reader)
      authenticate_as(user)

      get :index, params: {}, as: :json

      expect(response.parsed_body["data"].map { |e| e["name"] }).not_to include("Someone Else")
      expect(other).to be_present
    end
  end

end
