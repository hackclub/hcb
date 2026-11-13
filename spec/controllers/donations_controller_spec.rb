# frozen_string_literal: true

require "rails_helper"

RSpec.describe DonationsController do
  include SessionSupport
  include DonationSupport
  render_views

  let(:event) { create(:event) }
  let(:user) { create(:user) }
  let(:donation) { create(:donation, event:, aasm_state: "in_transit") }

  before do
    stub_donation_payment_intent_creation
    create_session(user, verified: true)
  end

  describe "GET receipt" do
    it "routes to the receipt rather than the public payment page" do
      expect(get: receipt_donation_path(donation, format: :pdf)).to route_to(
        controller: "donations", action: "receipt", id: donation.to_param, format: "pdf"
      )
    end

    it "lets a manager download a PDF" do
      create(:organizer_position, user:, event:, role: :manager)

      get :receipt, params: { id: donation.hashid }, format: :pdf

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("application/pdf")
      expect(response.headers["Content-Disposition"]).to include("attachment", donation.public_id)
      expect(response.body).to start_with("%PDF-")
    end

    it "lets an admin download a deposited donation's receipt" do
      user.update!(access_level: :admin)
      donation.update!(aasm_state: "deposited")

      get :receipt, params: { id: donation.hashid }, format: :pdf

      expect(response).to have_http_status(:ok)
      expect(response.body).to start_with("%PDF-")
    end

    [:reader, :member].each do |role|
      it "denies #{role}s access" do
        create(:organizer_position, user:, event:, role:)

        get :receipt, params: { id: donation.hashid }, format: :pdf

        expect(response).to redirect_to(root_path)
      end
    end

    it "denies managers of another organization access" do
      create(:organizer_position, user:, role: :manager)

      get :receipt, params: { id: donation.hashid }, format: :pdf

      expect(response).to redirect_to(root_path)
    end

    %w[pending failed refunded].each do |state|
      it "does not issue receipts for #{state} donations" do
        create(:organizer_position, user:, event:, role: :manager)
        donation.update!(aasm_state: state)

        get :receipt, params: { id: donation.hashid }, format: :pdf

        expect(response).to redirect_to(root_path)
      end
    end
  end
end
