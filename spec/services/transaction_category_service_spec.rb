# frozen_string_literal: true

require "rails_helper"

RSpec.describe TransactionCategoryService do
  describe ".new" do
    it "rejects unsupported objects" do
      expect do
        described_class.new(model: Object.new)
      end.to raise_error(ArgumentError, "unsupported model type: Object")
    end
  end

  describe "set!" do
    context "for canonical pending transactions" do
      it "sets the category and mapping if slug is present" do
        cpt = create(:canonical_pending_transaction)

        described_class.new(model: cpt).set!(slug: "rent")

        expect(cpt.category.slug).to eq("rent")
        expect(cpt.category_mapping.assignment_strategy).to eq("automatic")
      end

      it "allows the assignment strategy to be set" do
        cpt = create(:canonical_pending_transaction)

        described_class.new(model: cpt).set!(slug: "rent", assignment_strategy: "manual")

        expect(cpt.category.slug).to eq("rent")
        expect(cpt.category_mapping.assignment_strategy).to eq("manual")
      end

      it "clears the category and mapping if slug is blank" do
        cpt = create(:canonical_pending_transaction, category_slug: "rent")

        described_class.new(model: cpt).set!(slug: "")

        cpt.reload
        expect(cpt.category).to be_nil
        expect(cpt.category_mapping).to be_nil
      end
    end

    context "for canonical transactions" do
      it "sets the category and mapping if slug is present" do
        ct = create(:canonical_transaction)

        described_class.new(model: ct).set!(slug: "rent")

        expect(ct.category.slug).to eq("rent")
        expect(ct.category_mapping.assignment_strategy).to eq("automatic")
      end

      it "allows the assignment strategy to be set" do
        ct = create(:canonical_transaction)

        described_class.new(model: ct).set!(slug: "rent", assignment_strategy: "manual")

        expect(ct.category.slug).to eq("rent")
        expect(ct.category_mapping.assignment_strategy).to eq("manual")
      end

      it "clears the category and mapping if slug is blank" do
        ct = create(:canonical_transaction, category_slug: "rent")

        described_class.new(model: ct).set!(slug: "")

        ct.reload
        expect(ct.category).to be_nil
        expect(ct.category_mapping).to be_nil
      end
    end

    it "does not modify manual transactions" do
      ct = create(:canonical_transaction)

      # Perform an initial manual assignment
      described_class.new(model: ct).set!(slug: "rent", assignment_strategy: "manual")
      ct.reload
      expect(ct.category.slug).to eq("rent")
      expect(ct.category_mapping).to be_manual

      # Attempt to change it with an automatic assignment
      described_class.new(model: ct).set!(slug: "utilities", assignment_strategy: "automatic")
      ct.reload
      expect(ct.category.slug).to eq("rent")
      expect(ct.category_mapping).to be_manual

      # Actually change it with a manual assignment
      described_class.new(model: ct).set!(slug: "utilities", assignment_strategy: "manual")
      ct.reload
      expect(ct.category.slug).to eq("utilities")
      expect(ct.category_mapping).to be_manual
    end
  end

  describe "sync_from_stripe!" do
    context "for canonical transactions" do
      it "sets the category based on our mapping" do
        ct = create(
          :canonical_transaction,
          transaction_source: create(
            :raw_stripe_transaction,
            stripe_merchant_category: "bakeries",
          )
        )

        described_class.new(model: ct).sync_from_stripe!

        ct.reload
        expect(ct.category.slug).to eq("food-fun")
        expect(ct.category_mapping.assignment_strategy).to eq("automatic")
      end

      it "leaves the current category intact if one exists" do
        ct = create(
          :canonical_transaction,
          category_slug: "rent",
          transaction_source: create(
            :raw_stripe_transaction,
            stripe_merchant_category: "bakeries",
          )
        )

        described_class.new(model: ct).sync_from_stripe!

        ct.reload
        expect(ct.category.slug).to eq("rent")
      end

      it "ignores non-stripe transactions" do
        ct = create(:canonical_transaction)

        described_class.new(model: ct).sync_from_stripe!

        expect(ct.reload.category).to be_nil
      end

      it "ignores unmapped categories" do
        ct = create(
          :canonical_transaction,
          transaction_source: create(
            :raw_stripe_transaction,
            stripe_merchant_category: "definitely-not-a-thing",
          )
        )

        described_class.new(model: ct).sync_from_stripe!

        expect(ct.reload.category).to be_nil
      end
    end

    context "for canonical pending transactions" do
      it "sets the category based on our mapping" do
        cpt = create(
          :canonical_pending_transaction,
          raw_pending_stripe_transaction: create(
            :raw_pending_stripe_transaction,
            stripe_merchant_category: "bakeries",
          )
        )

        described_class.new(model: cpt).sync_from_stripe!

        cpt.reload
        expect(cpt.category.slug).to eq("food-fun")
        expect(cpt.category_mapping.assignment_strategy).to eq("automatic")
      end

      it "leaves the current category intact if one exists" do
        cpt = create(
          :canonical_pending_transaction,
          category_slug: "rent",
          raw_pending_stripe_transaction: create(
            :raw_pending_stripe_transaction,
            stripe_merchant_category: "bakeries",
          )
        )

        described_class.new(model: cpt).sync_from_stripe!

        cpt.reload
        expect(cpt.category.slug).to eq("rent")
      end

      it "ignores non-stripe transactions" do
        cpt = create(:canonical_pending_transaction)

        described_class.new(model: cpt).sync_from_stripe!

        expect(cpt.reload.category).to be_nil
      end

      it "ignores unmapped categories" do
        cpt = create(
          :canonical_pending_transaction,
          raw_pending_stripe_transaction: create(
            :raw_pending_stripe_transaction,
            stripe_merchant_category: "definitely-not-a-thing",
          )
        )

        described_class.new(model: cpt).sync_from_stripe!

        expect(cpt.reload.category).to be_nil
      end
    end
  end
end
