# frozen_string_literal: true

require "rails_helper"

RSpec.describe Subscription::LinkChargeJob do
  include_context "card locking charges"

  let(:stripe_card) { create(:stripe_card, :with_stripe_id, stripe_cardholder: create(:stripe_cardholder, user:), event:) }

  it "is enqueued when a charge settles and links it" do
    subscription = create(:subscription, stripe_card:, event:, merchant_network_id: "spotify-1", amount_cents: 11_99, last_charged_at: 31.days.ago)

    hcb_code = perform_enqueued_jobs(only: described_class) do
      create_settled_card_charge(user:, stripe_card:, settled_at: 1.day.ago, amount_cents: -11_99, merchant_network_id: "spotify-1", merchant_name: "SPOTIFY")
    end

    expect(hcb_code.reload.subscription).to eq(subscription)
  end
end
