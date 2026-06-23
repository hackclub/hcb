# frozen_string_literal: true

require "rails_helper"

RSpec.describe Donation::AlertsController, type: :controller do
  include SessionSupport
  render_views

  let(:user) { create(:user) }
  let(:event) { create(:event) }
  let!(:organizer_position) { create(:organizer_position, user: user, event: event) }

  before do
    create_session(user, verified: true)
  end

  describe "#index" do
    it "returns a success response" do
      get :index, params: { event_id: event.friendly_id }
      expect(response).to be_successful
    end

    it "displays alerts" do
      alert = create(:donation_alert, event: event)

      get :index, params: { event_id: event.friendly_id }

      expect(response.body).to include(alert.alert_name)
    end
  end

  describe "#new" do
    it "returns a success response" do
      get :new, params: { event_id: event.friendly_id }
      expect(response).to be_successful
    end
  end

  describe "#create" do
    it "creates a new donation alert" do
      expect do
        post :create, params: { event_id: event.friendly_id }
      end.to change(Donation::Alert, :count).by(1)
    end

    it "creates an alert with default values" do
      post :create, params: { event_id: event.friendly_id }

      alert = Donation::Alert.last
      expect(alert.event).to eq(event)
      expect(alert.alert_name).to eq("Untitled alert")
      expect(alert.amount_cents).to eq(10_00)
      expect(alert.alert_message).to eq("")
      expect(alert.active).to be false
    end
  end

  describe "#update" do
    it "updates the alert attributes" do
      alert = create(:donation_alert, event: event)

      patch :update, params: {
        event_id: event.friendly_id,
        alerts: {
          alert.id.to_s => {
            alert_name: "Updated Name",
            amount_cents: "50.00",
            alert_message: "Updated message",
            active: "1"
          }
        }
      }

      alert.reload
      expect(alert.alert_name).to eq("Updated Name")
      expect(alert.amount_cents).to eq(50_00)
      expect(alert.alert_message).to eq("Updated message")
      expect(alert.active).to be true
    end
  end

  describe "#destroy" do
    it "deletes the alert" do
      alert = create(:donation_alert, event: event)

      expect do
        delete :destroy, params: { event_id: event.friendly_id, id: alert.id }
      end.to change(Donation::Alert, :count).by(-1)
    end
  end

  describe "#toggle_subscription" do
    let(:alert) { create(:donation_alert, event: event) }

    it "subscribes the user when not subscribed" do
      post :toggle_subscription, params: { event_id: event.friendly_id, id: alert.id }

      expect(alert.reload.subscribed?(user)).to be true
      expect(flash[:notice]).to eq("You've subscribed to this alert!")
    end

    it "unsubscribes the user when already subscribed" do
      alert.subscribe(user)

      post :toggle_subscription, params: { event_id: event.friendly_id, id: alert.id }

      expect(alert.reload.subscribed?(user)).to be false
      expect(flash[:notice]).to eq("You've unsubscribed from this alert.")
    end

    it "does not affect other users' subscriptions" do
      user2 = create(:user)
      create(:organizer_position, user: user2, event: event)
      alert.subscribe(user2)

      post :toggle_subscription, params: { event_id: event.friendly_id, id: alert.id }

      expect(alert.reload.subscribed?(user)).to be true
      expect(alert.reload.subscribed?(user2)).to be true
    end

    it "allows different users to have independent subscription states" do
      user2 = create(:user)
      create(:organizer_position, user: user2, event: event)

      alert.subscribe(user)

      expect(alert.subscribed?(user)).to be true
      expect(alert.subscribed?(user2)).to be false

      alert.subscribe(user2)

      expect(alert.subscribed?(user)).to be true
      expect(alert.subscribed?(user2)).to be true

      alert.unsubscribe(user)

      expect(alert.subscribed?(user)).to be false
      expect(alert.subscribed?(user2)).to be true
    end
  end

  describe "#subscribe_to_all" do
    before do
      allow(controller).to receive(:verify_authorized)
    end

    let!(:active_alert1) { create(:donation_alert, event: event, active: true) }
    let!(:active_alert2) { create(:donation_alert, event: event, active: true) }

    it "subscribes to all active alerts" do
      post :subscribe_to_all, params: { event_id: event.friendly_id }

      expect(active_alert1.reload.subscribed?(user)).to be true
      expect(active_alert2.reload.subscribed?(user)).to be true
      expect(flash[:notice]).to eq("Subscribed to all alerts.")
    end

    it "unsubscribes from all active alerts when already subscribed to all" do
      active_alert1.subscribe(user)
      active_alert2.subscribe(user)

      post :subscribe_to_all, params: { event_id: event.friendly_id }

      expect(active_alert1.reload.subscribed?(user)).to be false
      expect(active_alert2.reload.subscribed?(user)).to be false
      expect(flash[:notice]).to eq("Unsubscribed from all alerts.")
    end

    it "redirects non-members to root" do
      non_member = create(:user)
      create_session(non_member, verified: true)

      post :subscribe_to_all, params: { event_id: event.friendly_id }

      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq("You must be an organization member to subscribe.")
    end

    it "does not affect other users' subscriptions" do
      user2 = create(:user)
      create(:organizer_position, user: user2, event: event)
      active_alert1.subscribe(user2)

      post :subscribe_to_all, params: { event_id: event.friendly_id }

      expect(active_alert1.reload.subscribed?(user)).to be true
      expect(active_alert2.reload.subscribed?(user)).to be true
      expect(active_alert1.reload.subscribed?(user2)).to be true
    end

    it "only affects active alerts, not inactive ones" do
      inactive_alert = create(:donation_alert, event: event, active: false)

      post :subscribe_to_all, params: { event_id: event.friendly_id }

      expect(active_alert1.reload.subscribed?(user)).to be true
      expect(active_alert2.reload.subscribed?(user)).to be true
      expect(inactive_alert.reload.subscribed?(user)).to be false
    end
  end

  describe "authorization" do
    it "denies access to non-members for index" do
      non_member = create(:user)
      create_session(non_member, verified: true)

      get :index, params: { event_id: event.friendly_id }

      expect(response).not_to be_successful
    end
  end
end
