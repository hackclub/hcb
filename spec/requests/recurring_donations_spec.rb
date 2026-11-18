# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Recurring donations", type: :request do
  describe "GET /recurring/:id after Stripe confirms a new payment method" do
    let(:recurring_donation) do
      RecurringDonation.create!(
        event: create(:event),
        name: "Jane Smith",
        email: "jane@example.com",
        amount: 10_00,
        stripe_subscription_id: "sub_test",
        stripe_customer_id: "cus_test",
        stripe_status: "active",
        last4: "1111"
      )
    end

    before do
      allow(StripeService::SetupIntent).to receive(:retrieve).and_return(
        Stripe::SetupIntent.construct_from(
          id: "seti_test",
          object: "setup_intent",
          payment_method: { id: "pm_test", object: "payment_method", card: { last4: "4242" } }
        )
      )
    end

    def return_from_stripe
      get recurring_donation_path(recurring_donation.url_hash, setup_intent: "seti_test", redirect_status: "succeeded")
    end

    it "shows the new card and confirms the update" do
      return_from_stripe

      expect(response).to redirect_to(recurring_donation_path(recurring_donation.url_hash))
      expect(flash[:success]).to eq("Your payment details have been updated.")
      expect(recurring_donation.reload.last4).to eq("4242")
    end

    context "when the donation has been canceled" do
      before { recurring_donation.update!(stripe_status: "canceled") }

      it "keeps the old card and explains that nothing changed" do
        return_from_stripe

        expect(response).to redirect_to(recurring_donation_path(recurring_donation.url_hash))
        expect(flash[:success]).to be_nil
        expect(flash[:error]).to eq("This donation has been canceled, so your payment details weren't updated.")
        expect(recurring_donation.reload.last4).to eq("1111")
      end
    end
  end
end
