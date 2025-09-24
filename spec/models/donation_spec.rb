# frozen_string_literal: true

require "rails_helper"

RSpec.describe Donation, type: :model do
  include ActiveJob::TestHelper

  before do
    expect(StripeService::Customer).to(
      receive(:create)
        .and_return(
          Stripe::Customer.construct_from(
            id: "cus_#{SecureRandom.alphanumeric(10)}"
          )
        )
        .at_least(:once)
    )

    expect(StripeService::PaymentIntent).to(
      receive(:create)
        .and_return(
          Stripe::PaymentIntent.construct_from(
            id: "pi_#{SecureRandom.alphanumeric(10)}",
            amount: 12_34,
            amount_received: 0,
            status: "processing",
            client_secret: "pi_#{SecureRandom.alphanumeric(20)}"
          )
        )
        .at_least(:once)
    )
  end

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
    end.to change(enqueued_jobs, :size).by(1)
  end

  it "does not send email notifications for non-succeeded donations" do
    event = create(:event)

    expect do
      donation = create(:donation, event:, name: "John Appleseed", email: "john@hackclub.com")
    end.to change(enqueued_jobs, :size).by(0)
  end

end
