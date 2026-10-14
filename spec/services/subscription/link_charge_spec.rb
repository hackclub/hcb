# frozen_string_literal: true

require "rails_helper"

RSpec.describe Subscription::LinkCharge do
  include_context "card locking charges"

  let(:stripe_card) { create(:stripe_card, :with_stripe_id, stripe_cardholder: create(:stripe_cardholder, user:), event:) }

  def charge(at, amount_cents: -11_99, network_id: "spotify-1", name: "SPOTIFY")
    create_settled_card_charge(user:, stripe_card:, settled_at: at, amount_cents:, merchant_network_id: network_id, merchant_name: name)
  end

  context "with subscriptions enabled" do
    before { Flipper.enable(Subscription::FLAG, event) }

    let!(:subscription) do
      create(:subscription, stripe_card:, event:, merchant_network_id: "spotify-1", amount_cents: 11_99, last_charged_at: 31.days.ago)
    end

    it "links a matching charge when it settles" do
      hcb_code = charge(1.day.ago)

      expect(hcb_code.reload.subscription).to eq(subscription)
      expect(subscription.reload.last_charged_at).to be_within(1.second).of(hcb_code.datetime)
    end

    it "waives the receipt on a charge after the first" do
      subscription.update!(last_charged_at: nil)
      first = charge(31.days.ago)
      second = charge(1.day.ago)

      expect(first.reload.subscription).to eq(subscription)
      expect(second.reload.subscription).to eq(subscription)
      expect(first.receipt_required?).to be(true)
      expect(second.receipt_required?).to be(false)
    end

    it "doesn't link a charge for a different amount" do
      expect(charge(1.day.ago, amount_cents: -12_99).reload.subscription).to be_nil
    end

    it "doesn't link a charge that's off-cadence" do
      expect(charge(21.days.ago).reload.subscription).to be_nil
    end

    it "doesn't link a charge at another merchant" do
      expect(charge(1.day.ago, network_id: "apple-1", name: "APPLE").reload.subscription).to be_nil
    end

    it "is idempotent" do
      hcb_code = charge(1.day.ago).reload
      other = create(:subscription, stripe_card:, event:, merchant_network_id: "spotify-1", amount_cents: 5_00)

      expect { described_class.new(hcb_code:).run }.not_to(change { hcb_code.reload.subscription_id })
      expect(other.hcb_codes).to be_empty
    end

    it "detects a new subscription when nothing matches" do
      subscription.destroy!

      charge(62.days.ago, network_id: "vercel-1", name: "VERCEL")
      charge(32.days.ago, network_id: "vercel-1", name: "VERCEL")
      expect(Subscription.count).to eq(0)

      third = charge(2.days.ago, network_id: "vercel-1", name: "VERCEL")

      detected = Subscription.sole
      expect(detected).to have_attributes(merchant_network_id: "vercel-1", source: "charges", cadence: "monthly")
      expect(detected.hcb_codes.count).to eq(3)
      expect(third.reload.receipt_required?).to be(false)
    end

    it "skips detection when asked to" do
      hcb_code = charge(1.day.ago, network_id: "vercel-1", name: "VERCEL").reload
      expect(Subscription::Detect).not_to receive(:new)

      described_class.new(hcb_code:, detect: false).run
    end
  end

  it "does nothing when subscriptions aren't enabled for the organization" do
    create(:subscription, stripe_card:, event:, merchant_network_id: "spotify-1", amount_cents: 11_99, last_charged_at: 31.days.ago)

    hcb_code = charge(1.day.ago)

    expect(described_class.new(hcb_code:).run).to be_nil
    expect(hcb_code.reload.subscription).to be_nil
  end
end
