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
  end
end
