# frozen_string_literal: true

require "rails_helper"

RSpec.describe SendDonationAlertsJob, type: :job do
  include ActiveJob::TestHelper

  before do
    allow(StripeService::Customer).to receive(:create).and_return(
      Stripe::Customer.construct_from(id: "cus_#{SecureRandom.alphanumeric(10)}")
    )
    allow(StripeService::PaymentIntent).to receive(:create).and_return(
      Stripe::PaymentIntent.construct_from(
        id: "pi_#{SecureRandom.alphanumeric(10)}",
        amount: 50_00,
        amount_received: 0,
        status: "processing",
        client_secret: "pi_secret_#{SecureRandom.alphanumeric(10)}"
      )
    )
  end

  describe "#perform" do
    it "calls DonationService::Alert with the donation" do
      donation = create(:donation)
      service = instance_double(DonationService::Alert)

      expect(DonationService::Alert).to receive(:new).with(donation).and_return(service)
      expect(service).to receive(:run)

      described_class.perform_now(donation.id)
    end

    it "enqueues the job" do
      donation = create(:donation)

      expect {
        described_class.perform_later(donation.id)
      }.to have_enqueued_job(described_class).with(donation.id)
    end

    it "raises an error when donation is not found" do
      expect {
        described_class.perform_now(-1)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
