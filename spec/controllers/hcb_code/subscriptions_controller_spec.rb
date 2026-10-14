# frozen_string_literal: true

require "rails_helper"

RSpec.describe HcbCode::SubscriptionsController do
  include SessionSupport
  include_context "card locking charges"

  let(:organizer) { create(:user) }
  let(:stripe_card) { create(:stripe_card, :with_stripe_id, stripe_cardholder: create(:stripe_cardholder, user:), event:) }
  let!(:hcb_code) { create_settled_card_charge(user:, stripe_card:, settled_at: 10.days.ago, amount_cents: -11_99, merchant_network_id: "spotify-1", merchant_name: "SPOTIFY") }

  before do
    create(:organizer_position, user: organizer, event:)
    create_session(organizer, verified: true)
    Flipper.enable(Subscription::FLAG, event)
  end

  describe "#create" do
    it "creates a subscription from the charge and links it" do
      post :create, params: { id: hcb_code.hashid, subscription: { name: "Spotify", cadence: "monthly" } }

      subscription = Subscription.sole
      expect(subscription).to have_attributes(
        name: "Spotify", amount_cents: 11_99, cadence: "monthly", cadence_days: 30, source: "manual",
        merchant_network_id: "spotify-1", merchant_name: "SPOTIFY", stripe_card:, event:, created_by: organizer
      )
      expect(hcb_code.reload.subscription).to eq(subscription)
      expect(subscription.first_hcb_code).to eq(hcb_code)
      expect(hcb_code.receipt_required?).to be(true)
    end

    it "accepts a custom cadence" do
      post :create, params: { id: hcb_code.hashid, subscription: { name: "Domain", cadence: "custom", cadence_days: "45" } }

      expect(Subscription.sole).to have_attributes(cadence: "custom", cadence_days: 45)
    end

    it "shows an error for an invalid cadence" do
      post :create, params: { id: hcb_code.hashid, subscription: { name: "Domain", cadence: "custom" } }

      expect(Subscription.count).to eq(0)
      expect(flash[:error]).to be_present
    end

    it "doesn't create a subscription without the flag" do
      Flipper.disable(Subscription::FLAG, event)

      post :create, params: { id: hcb_code.hashid, subscription: { name: "Spotify", cadence: "monthly" } }

      expect(Subscription.count).to eq(0)
    end

    it "doesn't let readers create a subscription" do
      reader = create(:user)
      create(:organizer_position, user: reader, event:, role: :reader)
      create_session(reader, verified: true)

      post :create, params: { id: hcb_code.hashid, subscription: { name: "Spotify", cadence: "monthly" } }

      expect(Subscription.count).to eq(0)
    end
  end
end
