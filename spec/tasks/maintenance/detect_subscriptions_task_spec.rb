# frozen_string_literal: true

require "rails_helper"

RSpec.describe Maintenance::DetectSubscriptionsTask do
  let!(:card) { create(:stripe_card, :with_stripe_id) }
  let!(:other_card) { create(:stripe_card, :with_stripe_id) }

  it "processes every active card" do
    create(:stripe_card, :with_stripe_id, stripe_status: "canceled")

    expect(described_class.new.collection).to contain_exactly(card, other_card)
  end

  it "runs detection for the card" do
    detect = instance_double(Subscription::Detect, run: [])
    expect(Subscription::Detect).to receive(:new).with(stripe_card: card).and_return(detect)

    described_class.new.process(card)
  end
end
