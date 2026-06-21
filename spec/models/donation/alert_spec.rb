# frozen_string_literal: true

require "rails_helper"

RSpec.describe Donation::Alert, type: :model do
  describe "validations" do
    it "is valid with valid attributes" do
      alert = build(:donation_alert)
      expect(alert).to be_valid
    end

    it "requires alert_name" do
      alert = build(:donation_alert, alert_name: nil)
      expect(alert).not_to be_valid
      expect(alert.errors[:alert_name]).to include("can't be blank")
    end

    it "requires amount_cents" do
      alert = build(:donation_alert, amount_cents: nil)
      expect(alert).not_to be_valid
      expect(alert.errors[:amount_cents]).to include("can't be blank")
    end

    it "requires amount_cents to be greater than 0" do
      alert = build(:donation_alert, amount_cents: 0)
      expect(alert).not_to be_valid
      expect(alert.errors[:amount_cents]).to include("must be greater than 0")
    end

    it "does not allow negative amount_cents" do
      alert = build(:donation_alert, amount_cents: -5)
      expect(alert).not_to be_valid
      expect(alert.errors[:amount_cents]).to include("must be greater than 0")
    end
  end

  describe "associations" do
    it "belongs to event" do
      alert = create(:donation_alert)
      expect(alert.event).to be_a(Event)
    end

    it "has and belongs to many users" do
      alert = create(:donation_alert)
      user = create(:user)
      alert.subscribe(user)
      expect(alert.users).to include(user)
    end
  end

  describe "scopes" do
    describe ".active" do
      it "returns only active alerts" do
        active_alert = create(:donation_alert, active: true)
        inactive_alert = create(:donation_alert, :inactive)

        expect(Donation::Alert.active).to include(active_alert)
        expect(Donation::Alert.active).not_to include(inactive_alert)
      end
    end
  end

  describe "#subscribe" do
    it "adds a user to the alert" do
      alert = create(:donation_alert)
      user = create(:user)

      alert.subscribe(user)

      expect(alert.users).to include(user)
    end

    it "does not add the same user twice" do
      alert = create(:donation_alert)
      user = create(:user)

      alert.subscribe(user)
      alert.subscribe(user)

      expect(alert.users.where(id: user.id).count).to eq(1)
    end

    it "allows multiple users to subscribe independently" do
      alert = create(:donation_alert)
      user1 = create(:user)
      user2 = create(:user)
      user3 = create(:user)

      alert.subscribe(user1)
      alert.subscribe(user2)
      alert.subscribe(user3)

      expect(alert.users.count).to eq(3)
      expect(alert.users).to contain_exactly(user1, user2, user3)
    end
  end

  describe "#unsubscribe" do
    it "removes a user from the alert" do
      alert = create(:donation_alert)
      user = create(:user)
      alert.subscribe(user)

      alert.unsubscribe(user)

      expect(alert.users).not_to include(user)
    end

    it "does not affect other subscribed users" do
      alert = create(:donation_alert)
      user1 = create(:user)
      user2 = create(:user)
      alert.subscribe(user1)
      alert.subscribe(user2)

      alert.unsubscribe(user1)

      expect(alert.users).to include(user2)
      expect(alert.users).not_to include(user1)
    end

    it "handles unsubscribing a user who is not subscribed" do
      alert = create(:donation_alert)
      user = create(:user)

      expect { alert.unsubscribe(user) }.not_to raise_error
      expect(alert.users).not_to include(user)
    end
  end

  describe "#subscribed?" do
    it "returns true when user is subscribed" do
      alert = create(:donation_alert)
      user = create(:user)
      alert.subscribe(user)

      expect(alert.subscribed?(user)).to be true
    end

    it "returns false when user is not subscribed" do
      alert = create(:donation_alert)
      user = create(:user)

      expect(alert.subscribed?(user)).to be false
    end

    it "returns correct status for each user independently" do
      alert = create(:donation_alert)
      user1 = create(:user)
      user2 = create(:user)

      alert.subscribe(user1)

      expect(alert.subscribed?(user1)).to be true
      expect(alert.subscribed?(user2)).to be false
    end
  end
end
