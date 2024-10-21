# frozen_string_literal: true

require "rails_helper"

RSpec.describe Donation, type: :modal do
  include ActiveJob::TestHelper

  it "is valid" do
    donation = create(:donation)
    expect(donation).to be_valid
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
    end.to have_enqueued_mail(DonationMailer, :donation_notification).once

    expect do
      donation3 = create(:donation, event:)
      donation3.message = "Happy hacking!"
      donation3.status = "succeeded"
      donation3.save
    end.to have_enqueued_mail(DonationMailer, :donation_with_message_notification).once
  end

  it "does not send multiple email notifications" do
    event = create(:event)

    expect do
      donation = create(:donation, event:)
      donation.status = "succeeded"
      donation.save

      donation.status = "succeeded"
      donation.save
    end.to change(enqueued_jobs, :size).by(1)
  end

  it "does not send email notifications for non-succeeded donations" do
    event = create(:event)

    expect do
      donation = create(:donation, event:, name: "John Appleseed", email: "john@hackclub.com")
    end.to change(enqueued_jobs, :size).by(0)
  end

end
