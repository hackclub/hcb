# frozen_string_literal: true

require "rails_helper"

RSpec.describe PublicActivity::Activity do
  describe ".preloaded_for_feed" do
    before do
      # Wires look up their recipient's bank at Column on creation.
      stub_request(:get, /api\.column\.com\/institutions\/.*/)
        .to_return(status: 200, body: '{"country_code": "DE"}', headers: { "Content-Type" => "application/json" })
    end

    it "loads a feed of trackables that do and don't define the preloaded associations" do
      user = create(:user)
      event = create(:event, :with_positive_balance)
      cpt = create(:canonical_pending_transaction, event:)
      raw = create(:raw_pending_stripe_transaction)
      create(:canonical_pending_transaction, raw_pending_stripe_transaction: raw, event:)

      described_class.create!(trackable: raw, key: "raw_pending_stripe_transaction.create", owner: user)
      described_class.create!(trackable: create(:wire, user:, event:), key: "wire.create", owner: user)
      described_class.create!(trackable: create(:comment, commentable: cpt.local_hcb_code, user:), key: "comment.create", owner: user)
      described_class.create!(trackable: create(:comment, commentable: event, user:), key: "comment.create", owner: user)
      described_class.create!(trackable: user, key: "user.create", owner: user)

      activities = described_class.preloaded_for_feed.to_a

      expect(activities.size).to eq(5)
      expect(activities.find { |a| a.trackable_type == "Wire" }.trackable.association(:ledger_item)).to be_loaded
      expect(activities.find { |a| a.trackable_type == "RawPendingStripeTransaction" }.trackable.canonical_pending_transaction.association(:ledger_item)).to be_loaded
    end
  end
end
