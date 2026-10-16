# frozen_string_literal: true

require "rails_helper"

RSpec.describe Subscription::Detect do
  include_context "card locking charges"

  let(:stripe_card) { create(:stripe_card, :with_stripe_id, stripe_cardholder: create(:stripe_cardholder, user:), event:) }

  def charge(at, amount_cents: -20_00, network_id: "vercel-1", name: "VERCEL INC")
    create_settled_card_charge(user:, stripe_card:, settled_at: at, amount_cents:, merchant_network_id: network_id, merchant_name: name)
  end

  def charges_at(*times, **options)
    times.map { |at| charge(at, **options) }
  end

  def detect(**options)
    described_class.new(stripe_card:, **options).run
  end

  it "detects a monthly subscription charged on the 1st" do
    charges_at(*[6, 7, 8, 9].map { |month| Time.zone.local(2026, month, 1, 12) })

    subscription = detect.sole
    expect(subscription).to have_attributes(
      cadence: "monthly", cadence_days: 30, amount_cents: 20_00,
      merchant_network_id: "vercel-1", merchant_name: "VERCEL INC"
    )
    expect(subscription.hcb_codes.count).to eq(4)
  end

  it "detects a biweekly subscription" do
    charges_at(43.days.ago, 29.days.ago, 15.days.ago, 1.day.ago)

    expect(detect.sole).to have_attributes(cadence: "biweekly", cadence_days: 14)
  end

  it "detects a monthly subscription with a skipped month" do
    charges_at(120.days.ago, 90.days.ago, 30.days.ago, 1.day.ago)

    expect(detect.sole).to have_attributes(cadence: "monthly")
  end

  it "detects a custom cadence" do
    charges_at(136.days.ago, 91.days.ago, 46.days.ago, 1.day.ago)

    expect(detect.sole).to have_attributes(cadence: "custom", cadence_days: 45)
  end

  it "only detects the amount that was charged at least three times" do
    charges_at(61.days.ago, 31.days.ago, 1.day.ago)
    charges_at(50.days.ago, 20.days.ago, amount_cents: -45_00)

    expect(detect.sole.amount_cents).to eq(20_00)
  end

  it "ignores the same merchant at varying amounts" do
    [-4_50, -5_25, -3_75, -6_10].each_with_index do |amount_cents, i|
      charge((i * 7).days.ago - 1.day, amount_cents:, network_id: "coffee-1", name: "COFFEE")
    end

    expect(detect).to be_empty
  end

  it "detects a yearly subscription from two charges" do
    charges_at(370.days.ago, 2.days.ago)

    subscription = detect.sole
    expect(subscription).to have_attributes(cadence: "yearly", cadence_days: 365)
    expect(subscription.hcb_codes.count).to eq(2)
  end

  it "ignores repeat purchases a few days apart" do
    charges_at(9.days.ago, 6.days.ago, 3.days.ago)

    expect(detect).to be_empty
  end

  it "leaves a repeat charge out rather than breaking the group" do
    first, second, repeat, last = charges_at(61.days.ago, 31.days.ago, 29.days.ago, 1.day.ago)

    subscription = detect.sole
    expect(subscription.cadence).to eq("monthly")
    expect(subscription.hcb_codes).to contain_exactly(first, second, last)
    expect(repeat.reload.subscription_id).to be_nil
  end

  it "needs at least three charges unless they're a year apart" do
    charges_at(31.days.ago, 1.day.ago)
    charges_at(120.days.ago, 2.days.ago, network_id: "other-1", name: "OTHER")

    expect(detect).to be_empty
  end

  it "ignores irregular gaps" do
    charges_at(100.days.ago, 90.days.ago, 30.days.ago, 1.day.ago)

    expect(detect).to be_empty
  end

  it "skips charges already linked to a subscription" do
    linked, *rest = charges_at(61.days.ago, 31.days.ago, 1.day.ago)
    create(:subscription, stripe_card:, event:, merchant_network_id: "other", amount_cents: 20_00).then { |subscription| linked.update!(subscription:) }

    expect(detect).to be_empty
    expect(rest.map { |hcb_code| hcb_code.reload.subscription_id }).to all(be_nil)
  end

  it "doesn't duplicate an existing subscription" do
    charges_at(61.days.ago, 31.days.ago, 1.day.ago)
    create(:subscription, stripe_card:, event:, merchant_network_id: "vercel-1", amount_cents: 20_00)

    expect { expect(detect).to be_empty }.not_to change(Subscription, :count)
  end

  it "narrows detection to one merchant" do
    charges_at(61.days.ago, 31.days.ago, 1.day.ago)
    charges_at(62.days.ago, 32.days.ago, 2.days.ago, network_id: "spotify-1", name: "SPOTIFY")

    expect(detect(merchant_network_id: "spotify-1").sole.merchant_network_id).to eq("spotify-1")
  end

  it "doesn't change whether a receipt is required" do
    charges = charges_at(61.days.ago, 31.days.ago, 1.day.ago)

    expect { detect }.not_to(change { charges.map { |hcb_code| hcb_code.reload.receipt_required? } })
  end

  it "doesn't touch the charges' ledger items" do
    charges = charges_at(61.days.ago, 31.days.ago, 1.day.ago)

    expect { detect }.not_to(change { charges.map { |hcb_code| hcb_code.ledger_item.reload.updated_at } })
  end
end
