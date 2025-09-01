# frozen_string_literal: true

require "rails_helper"

RSpec.describe OneTimeJobs::BackfillCanonicalPendingTransactionCategories do
  it "sets canonical pending transaction categories based on stripe transactions" do
    cpt = create(
      :canonical_pending_transaction,
      raw_pending_stripe_transaction: create(
        :raw_pending_stripe_transaction,
        stripe_merchant_category: "bakeries",
      )
    )

    Sidekiq::Testing.inline! do
      described_class.perform_async
    end

    cpt.reload
    expect(cpt.category.slug).to eq("food-fun")
    expect(cpt.category_mapping.assignment_strategy).to eq("automatic")
  end
end
