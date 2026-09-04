# frozen_string_literal: true

require "rails_helper"

RSpec.describe Donation, type: :model do
  include ActiveJob::TestHelper
  include DonationSupport

  before do
    stub_donation_payment_intent_creation
  end

  it "is valid" do
    donation = create(:donation)
    expect(donation).to be_valid
  end

  describe "#showable_donor?" do
    it "is true for a donation made online" do
      expect(create(:donation)).to be_showable_donor
    end

    it "is true for an in-person donation whose donor left an email" do
      expect(create(:donation, in_person: true, email: "ada@example.com")).to be_showable_donor
    end

    it "is false for an in-person donation with no email to build an avatar from" do
      expect(create(:donation, in_person: true, email: nil)).not_to be_showable_donor
    end

    it "is false for an anonymous donation" do
      expect(create(:donation, anonymous: true)).not_to be_showable_donor
    end
  end

  it "sends the correct payment notification for each succeeded donation" do
    event = create(:event)

    expect do
      donation = create(:donation, event:)
      donation.status = "succeeded"
      donation.save
    end.to have_enqueued_mail(DonationMailer, :first_donation_notification).once

    expect do
      donation2 = create(:donation, event:)
      donation2.status = "succeeded"
      donation2.save
    end.to have_enqueued_mail(DonationMailer, :notification).once

    expect do
      donation3 = create(:donation, event:)
      donation3.message = "Happy hacking!"
      donation3.status = "succeeded"
      donation3.save
    end.to have_enqueued_mail(DonationMailer, :notification).once
  end

  it "does not send multiple email notifications" do
    event = create(:event)

    expect do
      donation = create(:donation, event:)
      donation.status = "succeeded"
      donation.save

      donation.status = "succeeded"
      donation.save
    end.to have_enqueued_mail(DonationMailer, :first_donation_notification).once
  end

  it "does not send email notifications for non-succeeded donations" do
    event = create(:event)

    expect do
      donation = create(:donation, event:, name: "John Appleseed", email: "john@hackclub.com")
    end.not_to have_enqueued_mail(DonationMailer, :first_donation_notification)
  end

end
