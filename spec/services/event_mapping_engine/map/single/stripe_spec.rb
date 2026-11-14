# frozen_string_literal: true

require "rails_helper"

RSpec.describe EventMappingEngine::Map::Single::Stripe do
  let(:stripe_card) { create(:stripe_card, :with_stripe_id) }
  let(:raw_pending_stripe_transaction) { create(:raw_pending_stripe_transaction, stripe_transaction_id: "iauth_mapped") }

  before do
    create(:canonical_pending_transaction, raw_pending_stripe_transaction:, category_slug: "rent")
  end

  def settle(raw_stripe_transaction, **attrs)
    create(:canonical_transaction, transaction_source: raw_stripe_transaction, **attrs)
  end

  it "maps the transaction to the card's event" do
    ct = settle(create(:raw_stripe_transaction, stripe_authorization_id: "iauth_mapped", stripe_card:))

    described_class.new(canonical_transaction: ct).run

    expect(ct.reload.event).to eq(stripe_card.event)
  end

  it "gives a refund the category of the charge it reverses" do
    settle(create(:raw_stripe_transaction, stripe_authorization_id: "iauth_mapped", stripe_card:), category_slug: "food-fun")
    refund = settle(create(:raw_stripe_transaction, :refund, stripe_authorization_id: "iauth_mapped", stripe_card:))

    described_class.new(canonical_transaction: refund).run

    refund.reload
    expect(refund.event).to eq(stripe_card.event)
    expect(refund.category.slug).to eq("food-fun")
  end

  it "does not map a transaction that is already mapped" do
    ct = settle(create(:raw_stripe_transaction, stripe_authorization_id: "iauth_mapped", stripe_card:))
    create(:canonical_event_mapping, canonical_transaction: ct, event: create(:event))

    expect { described_class.new(canonical_transaction: ct).run }.not_to change(CanonicalEventMapping, :count)
  end
end
