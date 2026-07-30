# frozen_string_literal: true

require "rails_helper"

RSpec.describe CardChargeRawStripeTransaction, type: :model do
  it "rejects a transaction from a different authorization" do
    rpst = create(:raw_pending_stripe_transaction, stripe_transaction_id: "iauth_one")
    other = create(:raw_stripe_transaction, stripe_authorization_id: "iauth_two")

    join = described_class.new(card_charge: rpst.card_charge, raw_stripe_transaction: other)

    expect(join).not_to be_valid
    expect(join.errors[:raw_stripe_transaction].sole).to include("iauth_one")
  end

  it "rejects a transaction whose authorization differs from an already-linked sibling's" do
    linked = create(:raw_stripe_transaction, stripe_authorization_id: "iauth_original")
    other = create(:raw_stripe_transaction, stripe_authorization_id: "iauth_other")

    join = described_class.new(card_charge: linked.card_charge, raw_stripe_transaction: other)

    expect(join).not_to be_valid
  end

  it "rejects a force capture joining a charge that has an authorization" do
    force_capture = create(:raw_stripe_transaction, stripe_authorization_id: nil)
    rpst = create(:raw_pending_stripe_transaction)

    join = described_class.new(card_charge: rpst.card_charge, raw_stripe_transaction: force_capture)

    expect(join).not_to be_valid
  end

  it "rejects merging two force captures into one charge" do
    first = create(:raw_stripe_transaction, stripe_authorization_id: nil)
    second = create(:raw_stripe_transaction, stripe_authorization_id: nil)

    join = described_class.new(card_charge: first.card_charge, raw_stripe_transaction: second)

    expect(join).not_to be_valid
  end
end
