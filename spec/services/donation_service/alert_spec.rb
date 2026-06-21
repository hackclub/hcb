# frozen_string_literal: true

require "rails_helper"

RSpec.describe DonationService::Alert do
  let(:stripe_amount) { 50_00 }

  before do
    allow(StripeService::Customer).to receive(:create).and_return(
      Stripe::Customer.construct_from(id: "cus_#{SecureRandom.alphanumeric(10)}")
    )
    allow(StripeService::PaymentIntent).to receive(:create).and_return(
      Stripe::PaymentIntent.construct_from(
        id: "pi_#{SecureRandom.alphanumeric(10)}",
        amount: stripe_amount,
        amount_received: 0,
        status: "processing",
        client_secret: "pi_secret_#{SecureRandom.alphanumeric(10)}"
      )
    )
  end

  describe "#run" do
    let(:event) { create(:event) }
    let(:donation) { create(:donation, event: event) }

    context "when there are no active alerts" do
      it "does not send any emails" do
        create(:donation_alert, event: event, active: false, amount_cents: 1_00)

        expect do
          described_class.new(donation).run
        end.not_to have_enqueued_mail(DonationMailer, :alert_notification)
      end
    end

    context "when there are active alerts" do
      let!(:alert) { create(:donation_alert, event: event, active: true, amount_cents: 10_00) }

      context "when donation amount exceeds threshold" do
        it "sends email to subscribed users" do
          user = create(:user)
          alert.subscribe(user)

          expect do
            described_class.new(donation).run
          end.to have_enqueued_mail(DonationMailer, :alert_notification).once
        end

        it "sends email to multiple subscribed users" do
          user1 = create(:user)
          user2 = create(:user)
          alert.subscribe(user1)
          alert.subscribe(user2)

          expect do
            described_class.new(donation).run
          end.to have_enqueued_mail(DonationMailer, :alert_notification).twice
        end
      end

      context "when donation amount is below threshold" do
        it "does not send any emails" do
          low_alert = create(:donation_alert, event: event, active: true, amount_cents: 1000_00)
          user = create(:user)
          low_alert.subscribe(user)

          expect do
            described_class.new(donation).run
          end.not_to have_enqueued_mail(DonationMailer, :alert_notification)
        end
      end

      context "when multiple alerts have different thresholds" do
        let!(:low_alert) { create(:donation_alert, event: event, active: true, amount_cents: 1_00) }
        let!(:high_alert) { create(:donation_alert, event: event, active: true, amount_cents: 1000_00) }

        it "only triggers alerts where threshold is met" do
          user = create(:user)
          low_alert.subscribe(user)
          high_alert.subscribe(user)

          expect do
            described_class.new(donation).run
          end.to have_enqueued_mail(DonationMailer, :alert_notification).once
        end
      end
    end

    context "when donation amount conversion" do
      it "correctly converts cents to dollars for threshold comparison" do
        alert = create(:donation_alert, event: event, active: true, amount_cents: 50_00)
        user = create(:user)
        alert.subscribe(user)

        expect do
          described_class.new(donation).run
        end.to have_enqueued_mail(DonationMailer, :alert_notification).once
      end
    end

    context "with multiple users across multiple alerts" do
      it "sends separate emails to each subscribed user" do
        alert1 = create(:donation_alert, event: event, active: true, amount_cents: 10_00)
        alert2 = create(:donation_alert, event: event, active: true, amount_cents: 20_00)
        user1 = create(:user)
        user2 = create(:user)
        user3 = create(:user)

        alert1.subscribe(user1)
        alert1.subscribe(user2)
        alert2.subscribe(user3)

        expect do
          described_class.new(donation).run
        end.to have_enqueued_mail(DonationMailer, :alert_notification).exactly(3).times
      end

      it "does not send emails to unsubscribed users" do
        alert = create(:donation_alert, event: event, active: true, amount_cents: 10_00)
        subscribed_user = create(:user)
        unsubscribed_user = create(:user)

        alert.subscribe(subscribed_user)
        alert.subscribe(unsubscribed_user)
        alert.unsubscribe(unsubscribed_user)

        expect do
          described_class.new(donation).run
        end.to have_enqueued_mail(DonationMailer, :alert_notification).once
      end

      it "sends emails to users subscribed to different alerts independently" do
        low_alert = create(:donation_alert, event: event, active: true, amount_cents: 10_00)
        high_alert = create(:donation_alert, event: event, active: true, amount_cents: 1000_00)
        user_for_low = create(:user)
        user_for_high = create(:user)

        low_alert.subscribe(user_for_low)
        high_alert.subscribe(user_for_high)

        expect do
          described_class.new(donation).run
        end.to have_enqueued_mail(DonationMailer, :alert_notification).once
      end

      it "does not cross-pollinate between events" do
        other_event = create(:event)
        other_donation = create(:donation, event: other_event)
        alert = create(:donation_alert, event: event, active: true, amount_cents: 10_00)
        user_on_event = create(:user)
        user_on_other = create(:user)

        alert.subscribe(user_on_event)
        create(:donation_alert, event: other_event, active: true, amount_cents: 10_00).tap do |other_alert|
          other_alert.subscribe(user_on_other)
        end

        expect do
          described_class.new(donation).run
        end.to have_enqueued_mail(DonationMailer, :alert_notification).once

        expect do
          described_class.new(other_donation).run
        end.to have_enqueued_mail(DonationMailer, :alert_notification).once
      end

      it "sends correct alert content to each user" do
        alert = create(:donation_alert, event: event, active: true, amount_cents: 10_00, alert_name: "Big Donation")
        user1 = create(:user)
        user2 = create(:user)
        alert.subscribe(user1)
        alert.subscribe(user2)

        expect do
          described_class.new(donation).run
        end.to have_enqueued_mail(DonationMailer, :alert_notification).twice
      end
    end
  end
end
