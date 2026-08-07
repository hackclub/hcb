# frozen_string_literal: true

require "rails_helper"

RSpec.describe RawStripeTransaction, type: :model do
  let(:raw_stripe_transaction) { create(:raw_stripe_transaction) }

  it "is valid" do
    expect(raw_stripe_transaction).to be_valid
  end

  describe "#likely_event" do
    it "returns the event associated with the stripe card" do
      stripe_card = raw_stripe_transaction.stripe_transaction["card"]
      sc = StripeCard.find_by(stripe_id: stripe_card)

      expect(raw_stripe_transaction.likely_event).to eq(sc.event)
    end
  end

  describe "#likely_card_grant" do
    it "returns nil when the stripe card has no card grant" do
      expect(raw_stripe_transaction.likely_card_grant).to be_nil
    end

    it "returns the card grant when one exists" do
      event = create(:event, :with_positive_balance)
      sc = create(:stripe_card, :with_stripe_id, event:)
      rst = create(:raw_stripe_transaction, stripe_card: sc)
      card_grant = create(:card_grant, stripe_card: sc, event:)

      expect(rst.likely_card_grant).to eq(card_grant)
    end
  end

  describe "#merchant_category" do
    it "returns the merchant category from the JSON data" do
      expect(raw_stripe_transaction.merchant_category).to eq("bakeries")
    end

    it "returns nil by default" do
      expect(described_class.new.merchant_category).to be_nil
    end
  end
end
