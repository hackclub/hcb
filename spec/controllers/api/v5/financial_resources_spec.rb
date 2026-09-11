# frozen_string_literal: true

require "rails_helper"

# The six financial resources share `Api::V5::ScopedResource`, so this covers
# the shape once rather than repeating it per controller: the policy scope
# decides membership, the organization filter only narrows, and the field tiers
# come from the same v3-derived rule as everywhere else.
RSpec.describe "v5 financial resources" do
  include DonationSupport

  render_views

  let(:transparent) { create(:event, :with_positive_balance, is_public: true) }
  let(:private_org) { create(:event, :with_positive_balance, is_public: false) }

  def authenticate_as(user)
    request.headers["Authorization"] = "Bearer #{create(:api_token, user:).token}"
  end

  describe Api::V5::DonationsController, type: :controller do
    before { stub_donation_payment_intent_creation }

    it "lists a transparent organization's donations anonymously, without the donor email" do
      create(:donation, event: transparent, email: "donor@example.com")

      get :index, params: {}, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["data"].size).to eq(1)
      expect(response.parsed_body["data"].first).not_to include("donor_email")
      expect(response.body).not_to include("donor@example.com")
    end

    it "does not list a private organization's donations anonymously" do
      create(:donation, event: private_org)

      get :index, params: {}, as: :json

      expect(response.parsed_body["data"]).to be_empty
    end

    it "gives the donor email to an organizer" do
      create(:donation, event: private_org, email: "donor@example.com")
      user = create(:user)
      create(:organizer_position, user:, event: private_org, role: :reader)
      authenticate_as(user)

      get :index, params: {}, as: :json

      expect(response.parsed_body["data"].first).to include("donor_email" => "donor@example.com")
    end
  end

  describe Api::V5::DisbursementsController, type: :controller do
    # A transfer sits between two organizations and must be listed from either
    # end — a reader of the destination sees an incoming transfer they did not
    # send.
    it "lists a transfer to a reader of the destination organization" do
      disbursement = create(:disbursement, source_event: create(:event, :with_positive_balance, is_public: false), event: private_org)
      user = create(:user)
      create(:organizer_position, user:, event: private_org, role: :reader)
      authenticate_as(user)

      get :index, params: {}, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["data"].map { |d| d["id"] }).to include(disbursement.public_id)
    end

    it "does not list a transfer between two organizations the viewer cannot read" do
      create(:disbursement,
             source_event: create(:event, :with_positive_balance, is_public: false),
             event: create(:event, :with_positive_balance, is_public: false))

      get :index, params: {}, as: :json

      expect(response.parsed_body["data"]).to be_empty
    end
  end

end
