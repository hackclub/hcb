# frozen_string_literal: true

require "rails_helper"

RSpec.describe Maintenance::BackfillCardChargeCategoriesTask do
  let(:stripe_card) { create(:stripe_card, :with_stripe_id) }
  let(:raw_pending_stripe_transaction) { create(:raw_pending_stripe_transaction, stripe_transaction_id: "iauth_backfill") }

  before do
    create(:canonical_pending_transaction, raw_pending_stripe_transaction:, category_slug: "rent")
  end

  def settle(raw_stripe_transaction, **attrs)
    create(:canonical_transaction, transaction_source: raw_stripe_transaction, **attrs)
  end

  def stripe_transaction(*traits)
    create(:raw_stripe_transaction, *traits, stripe_authorization_id: "iauth_backfill", stripe_card:)
  end

  it "collects uncategorized transactions on card charges" do
    categorized_capture = settle(stripe_transaction, category_slug: "rent")
    late_capture = settle(stripe_transaction)
    categorized_refund = settle(stripe_transaction(:refund), category_slug: "rent")
    uncategorized_refund = settle(stripe_transaction(:refund))
    not_a_card_charge = create(:canonical_transaction)

    expect(late_capture.ledger_item.linked_object).to be_a(CardCharge)
    expect(described_class.collection).to contain_exactly(late_capture, uncategorized_refund)
    expect(described_class.collection).not_to include(categorized_capture, categorized_refund, not_a_card_charge)
  end

  it "gives a refund the category of the charge it reverses" do
    settle(stripe_transaction, category_slug: "food-fun")
    refund = settle(stripe_transaction(:refund))

    described_class.process(refund)

    expect(refund.reload.category.slug).to eq("food-fun")
  end

  it "gives a late capture the category of the charge's first capture" do
    settle(stripe_transaction, category_slug: "food-fun")
    late_capture = settle(stripe_transaction)

    described_class.process(late_capture)

    expect(late_capture.reload.category.slug).to eq("food-fun")
  end
end
