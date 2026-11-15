# frozen_string_literal: true

require "rails_helper"

RSpec.describe Maintenance::DetectSubscriptionsTask do
  include_context "card locking charges"

  before { travel_to(Time.zone.local(2026, 11, 1, 12)) }

  let(:stripe_card) { create(:stripe_card, :with_stripe_id, stripe_cardholder: create(:stripe_cardholder, user:), event:) }

  def settle(at, network_id: "vercel-1", card: stripe_card)
    create_settled_card_charge(user:, stripe_card: card, settled_at: at, amount_cents: -20_00, merchant_network_id: network_id, charge_event: card.event).ledger_item
  end

  def run_task
    task = described_class.new
    task.collection.each { |ledger_and_merchant| task.process(ledger_and_merchant) }
  end

  it "detects a subscription from charges in any order" do
    items = [0, 30, 60, 120, 90].map { |day| settle(300.days.ago + day.days) }

    run_task

    expect(Subscription.sole.ledger_items).to match_array(items)
  end

  it "joins a subscription found from recent charges to its older charges" do
    items = (0..600).step(30).map { |day| settle(700.days.ago + day.days) }
    Subscription::Detect.new(items.last).run

    run_task

    expect(Subscription.sole.ledger_items).to match_array(items)
  end

  it "keeps each merchant's charges apart" do
    [0, 30, 60].each { |day| settle(300.days.ago + day.days) }
    [5, 35, 65].each { |day| settle(300.days.ago + day.days, network_id: "figma-1") }

    run_task

    expect(Subscription.pluck(:merchant_key)).to contain_exactly("vercel-1", "figma-1")
  end

  it "can be run again" do
    [0, 30, 60].each { |day| settle(300.days.ago + day.days) }

    run_task
    run_task

    expect(Subscription.sole.ledger_items.count).to eq(3)
  end

  it "rebuilds one ledger without touching another's subscriptions" do
    other_card = create(:stripe_card, :with_stripe_id, stripe_cardholder: stripe_card.stripe_cardholder, event: create(:event))
    [0, 30, 60].each { |day| Subscription::Detect.new(settle(300.days.ago + day.days, card: other_card)).run }
    other = Subscription.sole
    [0, 30, 60].each { |day| settle(300.days.ago + day.days) }

    Subscription::Detect.rebuild(ledger: event.ledger, merchant_key: "vercel-1")

    expect(other.reload.ledger_items.count).to eq(3)
    expect(Subscription.count).to eq(2)
  end

  it "deletes a subscription that has no charges left to detect" do
    items = [0, 30, 60].map { |day| settle(300.days.ago + day.days) }
    Subscription::Detect.new(items.last).run
    Ledger::Item.where(id: items).update_all(status: "reversed")

    run_task

    expect(Subscription.count).to eq(0)
  end

  it "skips merchants with fewer than two online charges on a ledger" do
    settle(300.days.ago)

    expect(described_class.new.collection).to be_empty
  end
end
