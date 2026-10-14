# frozen_string_literal: true

require "rails_helper"

RSpec.describe SubscriptionsController do
  include SessionSupport
  include_context "card locking charges"

  render_views

  let(:organizer) { create(:user) }
  let(:stripe_card) { create(:stripe_card, :with_stripe_id, stripe_cardholder: create(:stripe_cardholder, user:), event:) }
  let!(:first) { create_settled_card_charge(user:, stripe_card:, settled_at: 40.days.ago, merchant_network_id: "spotify-1") }
  let!(:second) { create_settled_card_charge(user:, stripe_card:, settled_at: 10.days.ago, merchant_network_id: "spotify-1") }
  let(:subscription) { create(:subscription, stripe_card:, event:, merchant_network_id: "spotify-1", amount_cents: 10_00) }

  before do
    create(:organizer_position, user: organizer, event:)
    create_session(organizer, verified: true)
    [first, second].each { |hcb_code| hcb_code.update!(subscription:) }
    subscription.sync_charges!
  end

  describe "#index" do
    it "lists the organization's subscriptions with totals" do
      get :index, params: { event_id: event.slug }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(subscription.name)
      expect(response.body).to include("$120.00")
    end
  end

  describe "#show" do
    it "shows the subscription and its charges" do
      get :show, params: { event_id: event.slug, id: subscription.hashid }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("$10.00/mo · $120.00/yr")
    end
  end

  describe "#update" do
    it "updates the name, amount and cadence" do
      patch :update, params: { event_id: event.slug, id: subscription.hashid, subscription: { name: "Music", amount: "12.50", cadence: "custom", cadence_days: "28" } }

      expect(subscription.reload).to have_attributes(name: "Music", amount_cents: 12_50, cadence: "custom", cadence_days: 28)
    end

    it "rejects an unknown cadence" do
      patch :update, params: { event_id: event.slug, id: subscription.hashid, subscription: { cadence: "hourly" } }

      expect(subscription.reload.cadence).to eq("monthly")
      expect(flash[:error]).to be_present
    end

    it "doesn't let readers edit" do
      reader = create(:user)
      create(:organizer_position, user: reader, event:, role: :reader)
      create_session(reader, verified: true)

      patch :update, params: { event_id: event.slug, id: subscription.hashid, subscription: { name: "Music" } }

      expect(subscription.reload.name).to eq("Spotify")
    end
  end

  describe "#cancel" do
    it "marks the subscription as canceled" do
      post :cancel, params: { event_id: event.slug, id: subscription.hashid }

      expect(subscription.reload).to be_canceled
      expect(subscription.canceled_at).to be_present
      expect(second.reload.receipt_required?).to be(false)
    end
  end

  describe "#destroy" do
    it "unlinks the charges and requires receipts again" do
      expect(second.reload.receipt_required?).to be(false)

      perform_enqueued_jobs(only: Subscription::ResyncChargesJob) do
        delete :destroy, params: { event_id: event.slug, id: subscription.hashid }
      end

      expect(Subscription.exists?(subscription.id)).to be(false)
      expect(second.reload.subscription_id).to be_nil
      expect(second.receipt_required?).to be(true)
      expect(second.ledger_item.reload.receipt_required).to be(true)
    end
  end
end
