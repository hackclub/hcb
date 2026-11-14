# frozen_string_literal: true

require "rails_helper"

RSpec.describe Maintenance::BackfillCardChargeRefundCategoriesTask do
  let(:stripe_card) { create(:stripe_card, :with_stripe_id) }
  let(:raw_pending_stripe_transaction) { create(:raw_pending_stripe_transaction, stripe_transaction_id: "iauth_backfill") }

  before do
    create(:canonical_pending_transaction, raw_pending_stripe_transaction:, category_slug: "rent")
  end

  def settle(raw_stripe_transaction, **attrs)
    create(:canonical_transaction, transaction_source: raw_stripe_transaction, **attrs)
  end

  it "collects refunds that have no category" do
    capture = settle(create(:raw_stripe_transaction, stripe_authorization_id: "iauth_backfill", stripe_card:))
    categorized_refund = settle(create(:raw_stripe_transaction, :refund, stripe_authorization_id: "iauth_backfill", stripe_card:), category_slug: "rent")
    uncategorized_refund = settle(create(:raw_stripe_transaction, :refund, stripe_authorization_id: "iauth_backfill", stripe_card:))

    expect(described_class.collection).to contain_exactly(uncategorized_refund)
    expect(described_class.collection).not_to include(capture, categorized_refund)
  end

  it "gives a refund the category of the charge it reverses" do
    settle(create(:raw_stripe_transaction, stripe_authorization_id: "iauth_backfill", stripe_card:), category_slug: "food-fun")
    refund = settle(create(:raw_stripe_transaction, :refund, stripe_authorization_id: "iauth_backfill", stripe_card:))

    described_class.process(refund)

    expect(refund.reload.category.slug).to eq("food-fun")
  end
end
