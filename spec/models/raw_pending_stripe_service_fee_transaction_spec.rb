# frozen_string_literal: true

require "rails_helper"

RSpec.describe RawPendingStripeServiceFeeTransaction, type: :model do
  before do
    # StripeServiceFee creates a StripeTopup on create, which calls the Stripe API.
    stub_request(:post, "https://api.stripe.com/v1/topups")
      .to_return(status: 200, body: { id: "tu_1" }.to_json, headers: {})
  end

  # A raw pending stripe service fee transaction requires a StripeServiceFee
  # (belongs_to), so we build it through one rather than a dedicated factory —
  # the same way StripeServiceFeeService::CreateCanonicalPendingTransaction does.
  let(:stripe_service_fee) do
    create(:stripe_service_fee, amount_cents: -12_34, stripe_description: "Test fee")
  end
  let(:raw_pending_stripe_service_fee_transaction) do
    stripe_service_fee.create_raw_pending_stripe_service_fee_transaction!(
      date_posted: stripe_service_fee.created_at.to_date,
      amount_cents: stripe_service_fee.amount_cents
    )
  end

  it "is valid" do
    expect(raw_pending_stripe_service_fee_transaction).to be_valid
  end

  describe "#date" do
    it "returns the date_posted" do
      expect(raw_pending_stripe_service_fee_transaction.date)
        .to eq(raw_pending_stripe_service_fee_transaction.date_posted)
    end
  end

  describe "#memo" do
    it "returns the stripe description" do
      expect(raw_pending_stripe_service_fee_transaction.memo).to eq(stripe_service_fee.stripe_description)
    end
  end
end
