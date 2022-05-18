# frozen_string_literal: true

require "rails_helper"

RSpec.describe PartnerDonation, type: :model, skip: true do
  fixtures "partner_donations", "events"

  let(:partner_donation) { partner_donations(:partner_donation1) }

  it "is valid" do
    expect(partner_donation).to be_valid
  end

  context "hcb code" do
    let(:event) { events(:event1) }

    it "generates a hcb code" do
      pd = event.partner_donations.create!

      expect(pd.reload.hcb_code).to_not be_nil
    end
  end

  context "hcb_metadata_identifier" do
    let(:event) { events(:event1) }

    it "generates a donation identifier" do
      pd = event.partner_donations.create!

      expect(pd.hcb_metadata_identifier).to_not be_nil
    end
  end
end
