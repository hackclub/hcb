# frozen_string_literal: true

require "rails_helper"

RSpec.describe Maintenance::DetectSubscriptionsTask do
  let(:flagged_event) { create(:event) }
  let(:other_event) { create(:event) }
  let!(:flagged_card) { create(:stripe_card, :with_stripe_id, event: flagged_event) }
  let!(:other_card) { create(:stripe_card, :with_stripe_id, event: other_event) }

  before { Flipper.enable(Subscription::FLAG, flagged_event) }

  it "only processes active cards on organizations with subscriptions enabled" do
    create(:stripe_card, :with_stripe_id, event: flagged_event, stripe_status: "canceled")

    expect(described_class.new.collection).to contain_exactly(flagged_card)
  end

  it "processes every active card when the flag is fully enabled" do
    Flipper.enable(Subscription::FLAG)

    expect(described_class.new.collection).to contain_exactly(flagged_card, other_card)
  end

  it "runs detection for the card" do
    detect = instance_double(Subscription::Detect, run: [])
    expect(Subscription::Detect).to receive(:new).with(stripe_card: flagged_card).and_return(detect)

    described_class.new.process(flagged_card)
  end
end
