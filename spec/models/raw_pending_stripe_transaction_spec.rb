# frozen_string_literal: true

require "rails_helper"

RSpec.describe RawPendingStripeTransaction, type: :model do
  let(:raw_pending_stripe_transaction) { create(:raw_pending_stripe_transaction) }

  it "is valid" do
    expect(raw_pending_stripe_transaction).to be_valid
  end

  describe "#authorization_method" do
    it "returns it in human friendly form" do
      expect(raw_pending_stripe_transaction.authorization_method).to eql("online")
    end
  end

  describe "#merchant_category" do
    it "returns the merchant category from the JSON data" do
      expect(raw_pending_stripe_transaction.merchant_category).to eq("bakeries")
    end

    it "returns nil by default" do
      expect(described_class.new.merchant_category).to be_nil
    end
  end
end
