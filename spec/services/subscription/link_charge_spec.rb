# frozen_string_literal: true

require "rails_helper"

RSpec.describe Subscription::LinkCharge do
  include_context "card locking charges"

  let(:stripe_card) { create(:stripe_card, :with_stripe_id, stripe_cardholder: create(:stripe_cardholder, user:), event:) }

  def charge(at, amount_cents: -11_99, network_id: "spotify-1", name: "SPOTIFY")
    create_settled_card_charge(user:, stripe_card:, settled_at: at, amount_cents:, merchant_network_id: network_id, merchant_name: name)
  end

  def link(hcb_code)
    described_class.new(hcb_code: hcb_code.reload).run
  end

  let!(:subscription) do
    create(:subscription, stripe_card:, event:, merchant_network_id: "spotify-1", amount_cents: 11_99, last_charged_at: 31.days.ago)
  end

  it "links a matching charge" do
    hcb_code = charge(1.day.ago)

    expect(link(hcb_code)).to eq(subscription)
    expect(hcb_code.reload.subscription).to eq(subscription)
    expect(subscription.reload.last_charged_at).to be_within(1.second).of(hcb_code.datetime)
  end

  it "doesn't link a charge for a different amount" do
    expect(link(charge(1.day.ago, amount_cents: -12_99))).to be_nil
  end

  it "doesn't link a charge too soon after the last one" do
    expect(link(charge(21.days.ago))).to be_nil
  end

  it "links a charge after the billing date moved, and tracks the new date" do
    subscription.update!(last_charged_at: 60.days.ago)
    hcb_code = charge(16.days.ago)

    expect(link(hcb_code)).to eq(subscription)
    expect(subscription.reload.last_charged_at).to be_within(1.second).of(hcb_code.datetime)
  end

  it "doesn't link a charge at another merchant" do
    expect(link(charge(1.day.ago, network_id: "apple-1", name: "APPLE"))).to be_nil
  end

  it "is idempotent" do
    hcb_code = charge(1.day.ago)
    link(hcb_code)
    create(:subscription, stripe_card:, event:, merchant_network_id: "spotify-1", amount_cents: 5_00)

    expect { link(hcb_code) }.not_to(change { hcb_code.reload.subscription_id })
  end

  it "detects a new subscription when nothing matches" do
    subscription.destroy!

    link(charge(62.days.ago, network_id: "vercel-1", name: "VERCEL"))
    link(charge(32.days.ago, network_id: "vercel-1", name: "VERCEL"))
    expect(Subscription.count).to eq(0)

    third = charge(2.days.ago, network_id: "vercel-1", name: "VERCEL")
    detected = link(third)

    expect(detected).to have_attributes(merchant_network_id: "vercel-1", cadence: "monthly")
    expect(detected.hcb_codes.count).to eq(3)
  end
end
