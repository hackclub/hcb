# frozen_string_literal: true

require "rails_helper"

RSpec.describe DonationMailer, type: :mailer do
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

  describe "#alert_notification" do
    let(:event) { create(:event, name: "Test Event") }
    let(:donation) { create(:donation, event: event, name: "John Doe") }
    let(:alert) { create(:donation_alert, event: event, alert_name: "Big Donation", amount_cents: 10_00, alert_message: "Great job!") }
    let(:user) { create(:user, email: "subscriber@example.com") }

    subject(:mail) { DonationMailer.with(user: user, donation: donation, alert: alert).alert_notification }

    it "sends to the correct recipient" do
      expect(mail.to).to eq(["subscriber@example.com"])
    end

    it "has the correct subject" do
      expect(mail.subject).to eq("Test Event received a donation of $50.00!")
    end

    it "includes the donation amount" do
      expect(mail.body.encoded).to include("$50.00")
    end

    it "includes the event name" do
      expect(mail.body.encoded).to include("Test Event")
    end

    it "includes the donor name" do
      expect(mail.body.encoded).to include("John Doe")
    end

    it "includes the alert name" do
      expect(mail.body.encoded).to include("Big Donation")
    end

    it "includes the alert message" do
      expect(mail.body.encoded).to include("Great job!")
    end

    context "when donor name is not present" do
      it "does not include donor section" do
        donation_without_name = build(:donation, event: event)
        allow(donation_without_name).to receive(:name).and_return(nil)

        mail = DonationMailer.with(user: user, donation: donation_without_name, alert: alert).alert_notification

        expect(mail.body.encoded).not_to include("Donor:")
      end
    end

    context "when alert message is not present" do
      it "does not include custom message section" do
        alert_without_message = create(:donation_alert, event: event, alert_message: nil)

        mail = DonationMailer.with(user: user, donation: donation, alert: alert_without_message).alert_notification

        expect(mail.body.encoded).not_to include("Custom Message:")
      end
    end
  end
end
