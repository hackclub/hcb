# frozen_string_literal: true

require "rails_helper"

RSpec.describe Subscription::Detect do
  include_context "card locking charges"

  let(:stripe_card) { create(:stripe_card, :with_stripe_id, stripe_cardholder: create(:stripe_cardholder, user:), event:) }
  let(:start) { 300.days.ago }

  # Settles a charge `day` days after the start and runs detection on it, as
  # the job does. Returns the charge's subscription, if any.
  def charge(day, amount_cents: -20_00, network_id: "vercel-1", card: stripe_card)
    hcb_code = create_settled_card_charge(user:, stripe_card: card, settled_at: start + day.days, amount_cents:, merchant_network_id: network_id)
    described_class.new(hcb_code.ledger_item).run
    hcb_code.ledger_item.reload.subscription
  end

  it "detects a flat monthly subscription on the third charge" do
    expect(charge(0)).to be_nil
    expect(charge(31)).to be_nil

    expect(charge(61)).to have_attributes(
      cadence_days: 30, cadence_label: "monthly", amount_cents: 20_00, variable_amount: false,
      merchant_key: "vercel-1", ledger: event.ledger, payment_rail: stripe_card,
      last_charged_at: be_within(1.second).of(start + 61.days),
      next_expected_at: be_within(1.second).of(start + 91.days)
    )
    expect(Subscription.sole.ledger_items.count).to eq(3)
  end

  it "detects other cadences, with a skipped cycle" do
    [0, 45, 135].each { |day| charge(day) }

    expect(charge(180)).to have_attributes(cadence_days: 45, cadence_label: "every 45 days")
  end

  it "detects a yearly subscription from two charges" do
    charge(-100)

    expect(charge(270)).to have_attributes(cadence_days: 365)
  end

  it "detects usage-based billing as a variable amount" do
    charge(0, amount_cents: -31_40)
    charge(30, amount_cents: -18_05)

    expect(charge(61, amount_cents: -52_90)).to have_attributes(cadence_days: 30, variable_amount: true, amount_cents: 52_90)
    expect(charge(91, amount_cents: -7_00)).to eq(Subscription.sole)
  end

  it "ignores purchases that aren't on a cadence" do
    [0, 3, 6, 40, 47].each { |day| charge(day, amount_cents: -(5_00 + day)) }
    [0, 3, 6].each { |day| charge(day, network_id: "coffee-1") }

    expect(Subscription.count).to eq(0)
  end

  it "ignores in-person charges" do
    allow_any_instance_of(CardCharge).to receive(:card_present?).and_return(true)

    [0, 30, 60].each { |day| charge(day) }

    expect(Subscription.count).to eq(0)
  end

  context "with a monthly subscription due on day 90" do
    let!(:subscription) { [0, 30, 60].map { |day| charge(day) }.last }

    it "links a late charge and keeps the billing day" do
      expect(charge(101)).to eq(subscription)
      expect(subscription.reload.next_expected_at).to be_within(1.second).of(start + 120.days)
      expect(charge(120)).to eq(subscription)
    end

    it "leaves out a repeat charge" do
      expect(charge(62)).to be_nil
      expect(charge(90)).to eq(subscription)
    end

    it "follows a price change" do
      expect(charge(90, amount_cents: -22_00)).to eq(subscription)
      expect(subscription.reload.amount_cents).to eq(22_00)
    end

    it "follows the subscription to another card" do
      replacement = create(:stripe_card, :with_stripe_id, stripe_cardholder: stripe_card.stripe_cardholder, event:)

      expect(charge(90, card: replacement)).to eq(subscription)
      expect(subscription.reload.payment_rail).to eq(replacement)
    end

    it "keeps a different price at the same merchant separate" do
      other = [63, 93, 123].map { |day| charge(day, amount_cents: -99_00) }.last

      expect(other).to have_attributes(amount_cents: 99_00)
      expect(other).not_to eq(subscription)
      expect(subscription.reload.ledger_items.count).to eq(3)
    end

    it "is lapsed once a whole cycle is missed" do
      travel_to(start + 100.days) { expect(subscription.lapsed?).to be(false) }
      travel_to(start + 121.days) { expect(subscription.lapsed?).to be(true) }
    end

    it "does nothing for a charge that is already linked" do
      expect { described_class.new(subscription.ledger_items.last).run }.not_to(change { subscription.reload.next_expected_at })
    end
  end

  it "is enqueued when a card charge settles" do
    expect { create_settled_card_charge(user:, stripe_card:, settled_at: start) }.to have_enqueued_job(Subscription::DetectJob).at_least(:once)
  end

  it "is backfilled by the maintenance task" do
    [0, 30, 60].each do |day|
      create_settled_card_charge(user:, stripe_card:, settled_at: start + day.days, merchant_network_id: "vercel-1")
    end

    task = Maintenance::DetectSubscriptionsTask.new
    task.collection.order(:id).each { |ledger_item| task.process(ledger_item) }

    expect(Subscription.sole.ledger_items.count).to eq(3)
  end
end
