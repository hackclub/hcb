# frozen_string_literal: true

require "rails_helper"

RSpec.describe OneTimeJobs::BackfillCanonicalTransactionCategories do
  it "sets canonical transaction categories based on stripe transactions" do
    ct = create(
      :canonical_transaction,
      transaction_source: create(
        :raw_stripe_transaction,
        stripe_merchant_category: "bakeries",
      )
    )

    Sidekiq::Testing.inline! do
      described_class.perform_async
    end

    ct.reload
    expect(ct.category.slug).to eq("food-fun")
    expect(ct.category_mapping.assignment_strategy).to eq("automatic")
  end
end
