# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::V5::TransactionsController do
  include DonationSupport

  render_views

  before do
    allow_any_instance_of(UsersHelper).to receive(:profile_picture_for).and_return("https://gravatar.com/avatar/stubbed")
  end

  let(:transparent) { create(:event, :with_positive_balance, is_public: true) }
  let(:private_org) { create(:event, :with_positive_balance, is_public: false) }

  def authenticate_as(user)
    request.headers["Authorization"] = "Bearer #{create(:api_token, user:).token}"
  end

  describe "#index" do
    it "serves a transparent organization's ledger without a token" do
      get :index, params: { event_id: transparent.public_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to have_key("data")
    end

    it "refuses a private organization's ledger to an anonymous caller" do
      get :index, params: { event_id: private_org.public_id }, as: :json

      expect(response).to have_http_status(:forbidden)
    end

    it "serves a private organization's ledger to a reader" do
      user = create(:user)
      create(:organizer_position, user:, event: private_org, role: :reader)
      authenticate_as(user)

      get :index, params: { event_id: private_org.public_id }, as: :json

      expect(response).to have_http_status(:ok)
    end
  end

  describe "#show" do
    it "gates donor email behind org membership while publishing the donor name" do
      stub_donation_payment_intent_creation
      donation = create(:donation, event: transparent, amount: 1000, email: "donor@example.com")
      hcb_code = donation.local_hcb_code

      get :show, params: { id: hcb_code.public_id }, as: :json

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body.dig("donation", "donor")).to be_present
      expect(body["donation"]).not_to include("donor_email")
      expect(response.body).not_to include("donor@example.com")
    end
  end

end
