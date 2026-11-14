# frozen_string_literal: true

require "rails_helper"

RSpec.describe Subscription, type: :model do
  describe "cadence" do
    it "is named after its cadence_days bucket" do
      expect(build(:subscription, cadence_days: 7).cadence).to eq("weekly")
      expect(build(:subscription, cadence_days: 90).cadence_label).to eq("quarterly")
    end

    it "is custom for any other number of days" do
      subscription = build(:subscription, cadence_days: 45)

      expect(subscription.cadence).to eq("custom")
      expect(subscription.cadence_label).to eq("every 45 days")
    end

    it "requires positive cadence days" do
      expect(build(:subscription, cadence_days: 0)).not_to be_valid
    end
  end

  it "doesn't allow a duplicate subscription for the same card, merchant and amount" do
    existing = create(:subscription)

    expect(build(:subscription, stripe_card: existing.stripe_card)).not_to be_valid
    expect(build(:subscription, stripe_card: existing.stripe_card, amount_cents: 5_00)).to be_valid
  end

  describe "#matches?" do
    let(:subscription) { create(:subscription, last_charged_at: 30.days.ago) }

    def matches(**overrides)
      subscription.matches?(**{ merchant_network_id: "spotify-123", merchant_name: "SPOTIFY USA", amount_cents: -11_99, at: Time.current }.merge(overrides))
    end

    it "matches on network id, exact amount and timing" do
      expect(matches).to be(true)
    end

    it "falls back to a case-insensitive merchant name when a network id is missing" do
      subscription.update!(merchant_network_id: nil)

      expect(matches(merchant_network_id: nil, merchant_name: "spotify")).to be(true)
      expect(matches(merchant_network_id: nil, merchant_name: "Apple")).to be(false)
    end

    it "doesn't match another network id" do
      expect(matches(merchant_network_id: "other")).to be(false)
    end

    it "doesn't match a different amount" do
      expect(matches(amount_cents: -12_99)).to be(false)
    end

    it "doesn't match a charge too soon after the last one" do
      expect(matches(at: 30.days.ago + 10.days)).to be(false)
    end

    it "matches after any number of skipped cycles" do
      expect(matches(at: 30.days.ago + 61.days)).to be(true)
      expect(matches(at: 30.days.ago + 90.days)).to be(true)
      expect(matches(at: 30.days.ago + 150.days)).to be(true)
    end

    it "matches a charge slightly early" do
      expect(matches(at: 30.days.ago + 25.days)).to be(true)
      expect(matches(at: 30.days.ago + 23.days)).to be(false)
    end

    it "matches any time when there's no previous charge" do
      subscription.update!(last_charged_at: nil)

      expect(matches(at: 3.days.from_now)).to be(true)
    end
  end

  describe "#sync_charges!" do
    include_context "card locking charges"

    let(:stripe_card) { create(:stripe_card, :with_stripe_id, stripe_cardholder: create(:stripe_cardholder, user:), event:) }
    let(:subscription) { create(:subscription, stripe_card:, amount_cents: 10_00) }

    it "tracks the last and next expected charge" do
      first = create_settled_card_charge(user:, stripe_card:, settled_at: 40.days.ago).ledger_item.reload
      last = create_settled_card_charge(user:, stripe_card:, settled_at: 10.days.ago).ledger_item.reload

      [last, first].each { |ledger_item| ledger_item.update_column(:subscription_id, subscription.id) }
      subscription.sync_charges!

      expect(subscription.last_charged_at).to be_within(1.second).of(last.datetime)
      expect(subscription.next_expected_at).to be_within(1.second).of(last.datetime + 30.days)
    end
  end

  describe "#link!" do
    include_context "card locking charges"

    let(:stripe_card) { create(:stripe_card, :with_stripe_id, stripe_cardholder: create(:stripe_cardholder, user:), event:) }
    let(:subscription) { create(:subscription, stripe_card:, amount_cents: 10_00) }

    it "links the charge and tracks it as the last one" do
      ledger_item = create_settled_card_charge(user:, stripe_card:, settled_at: 10.days.ago).ledger_item.reload

      subscription.link!(ledger_item)

      expect(ledger_item.reload.subscription).to eq(subscription)
      expect(subscription.last_charged_at).to be_within(1.second).of(ledger_item.datetime)
    end

    it "doesn't touch the charge's ledger item" do
      ledger_item = create_settled_card_charge(user:, stripe_card:, settled_at: 10.days.ago).ledger_item.reload

      expect { subscription.link!(ledger_item) }.not_to(change { ledger_item.reload.updated_at })
    end
  end
end
