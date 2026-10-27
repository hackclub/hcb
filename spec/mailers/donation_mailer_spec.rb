# frozen_string_literal: true

require "rails_helper"

RSpec.describe DonationMailer do
  include DonationSupport

  describe "#donor_receipt" do
    it "tells the donor how the charge shows up on their statement" do
      stub_donation_payment_intent_creation
      event = create(:event, name: "Hack Club Assemble 2026 Hackathon", short_name: "Assemble")
      donation = create(:donation, event:)

      mail = described_class.with(donation:).donor_receipt

      expect(mail.body.encoded).to include("<strong>HCB* Assemble</strong>")
    end
  end
end
