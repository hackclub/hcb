# frozen_string_literal: true

require "rails_helper"

RSpec.describe RecurringDonation, type: :model do
  describe "#sync_with_stripe_subscription!" do
    def build_subscription(latest_invoice:)
      Stripe::Subscription.construct_from(
        id: "sub_1234", status: "active", customer: "cus_1234", canceled_at: nil, default_payment_method: nil,
        items: { data: [{ current_period_end: 1_900_000_000 }] },
        latest_invoice:
      )
    end

    it "reads the billing period from the subscription item and the intent from the default payment" do
      subscription = build_subscription(
        latest_invoice: {
          payments: {
            data: [
              { is_default: false, payment: { type: "payment_intent", payment_intent: { id: "pi_partial", client_secret: "pi_partial_secret" } } },
              { is_default: true, payment: { type: "payment_intent", payment_intent: { id: "pi_default", client_secret: "pi_default_secret" } } }
            ]
          }
        }
      )

      recurring_donation = described_class.new.sync_with_stripe_subscription!(subscription)

      expect(recurring_donation.stripe_payment_intent_id).to eq("pi_default")
      expect(recurring_donation.stripe_client_secret).to eq("pi_default_secret")
      expect(recurring_donation.stripe_current_period_end).to eq(Time.at(1_900_000_000))
      expect(recurring_donation.stripe_customer_id).to eq("cus_1234")
    end

    it "tolerates a subscription that has no invoice yet" do
      recurring_donation = described_class.new.sync_with_stripe_subscription!(build_subscription(latest_invoice: nil))

      expect(recurring_donation.stripe_payment_intent_id).to be_nil
      expect(recurring_donation.stripe_client_secret).to be_nil
    end
  end
end
