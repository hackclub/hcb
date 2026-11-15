# frozen_string_literal: true

require "rails_helper"

# Donors who don't recognize a charge on their statement tend to dispute it, so
# we tell them what it'll look like once they've donated.
RSpec.describe "Donation statement descriptor", type: :request do
  include DonationSupport

  let(:event) { create(:event, name: "Hack Club Assemble 2026 Hackathon", short_name: "Assemble") }

  before { stub_donation_payment_intent_creation }

  it "shows the statement descriptor once the donation is made" do
    donation = create(:donation, event:)

    get finished_donation_donations_path(event.slug, donation.url_hash)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("<strong>HCB* Assemble</strong>")
  end
end
