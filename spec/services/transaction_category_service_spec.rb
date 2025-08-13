# frozen_string_literal: true

require "rails_helper"

RSpec.describe TransactionCategoryService do
  describe "set!" do
    context "for canonical pending transactions" do
      it "sets the category and mapping if name is present" do
        cpt = create(:canonical_pending_transaction)

        described_class.new(model: cpt).set!(name: "Donations")

        expect(cpt.category.name).to eq("Donations")
        expect(cpt.category_mapping.assignment_strategy).to eq("automatic")
      end

      it "allows the assignment strategy to be set" do
        cpt = create(:canonical_pending_transaction)

        described_class.new(model: cpt).set!(name: "Donations", assignment_strategy: "manual")

        expect(cpt.category.name).to eq("Donations")
        expect(cpt.category_mapping.assignment_strategy).to eq("manual")
      end

      it "clears the category and mapping if name is blank" do
        cpt = create(:canonical_pending_transaction, category_name: "Donations")

        described_class.new(model: cpt).set!(name: "")

        cpt.reload
        expect(cpt.category).to be_nil
        expect(cpt.category_mapping).to be_nil
      end
    end

    context "for canonical transactions" do
      it "sets the category and mapping if name is present" do
        ct = create(:canonical_transaction)

        described_class.new(model: ct).set!(name: "Donations")

        expect(ct.category.name).to eq("Donations")
        expect(ct.category_mapping.assignment_strategy).to eq("automatic")
      end

      it "allows the assignment strategy to be set" do
        ct = create(:canonical_transaction)

        described_class.new(model: ct).set!(name: "Donations", assignment_strategy: "manual")

        expect(ct.category.name).to eq("Donations")
        expect(ct.category_mapping.assignment_strategy).to eq("manual")
      end

      it "clears the category and mapping if name is blank" do
        ct = create(:canonical_transaction, category_name: "Donations")

        described_class.new(model: ct).set!(name: "")

        ct.reload
        expect(ct.category).to be_nil
        expect(ct.category_mapping).to be_nil
      end
    end
  end
end
