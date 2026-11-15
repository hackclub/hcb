# frozen_string_literal: true

require "rails_helper"

RSpec.describe TransactionCategory::Definition do
  describe "db/data/transaction_categories.json" do
    it "is correctly structured" do
      contents = JSON.parse(File.read(Rails.root.join("db/data/transaction_categories.json")))

      expect(contents).to(be_a(Hash), "is not a JSON object")
      expect(contents.keys).to(eq(contents.keys.sort), "top-level keys are not sorted")

      # Keep a running list of all the stripe categories we see so we can detect
      # duplicates
      all_stripe_categories = Set.new

      contents.each do |slug, attributes|
        expect(attributes).to(be_a(Hash), "#{slug.inspect} property is not an object")

        attributes.each_key do |key|
          expect(["label", "stripe_merchant_categories", "hq_only"]).to(
            include(key),
            "#{slug.inspect} has unsupported key #{key.inspect}"
          )
        end

        expect(attributes["label"]).to(be_a(String).and(be_present), "#{slug.inspect} is missing a label")

        expect(attributes["hq_only"]).to(be_in([true, false, nil]), "#{slug.inspect} has an invalid hq_only property")

        stripe_categories = attributes["stripe_merchant_categories"]
        next if stripe_categories.nil?

        expect(stripe_categories).to(
          be_a(Array).and(be_present),
          "stripe_categories for #{slug.inspect} is not a populated array"
        )
        expect(stripe_categories).to(
          all(be_a(String).and(be_present)),
          "#{slug.inspect} must only contain strings in stripe_categories"
        )
        expect(stripe_categories).to(
          eq(stripe_categories.sort.uniq),
          "#{slug.inspect} must have sorted and unique stripe categories"
        )

        stripe_categories.each do |stripe_category|
          expect(YellowPages::Category.categories_by_key[stripe_category]).to(
            be_present,
            "stripe category #{stripe_category.inspect} for #{slug.inspect} must exist in YellowPages"
          )

          expect(all_stripe_categories.add?(stripe_category)).to(
            be_present,
            "stripe category #{stripe_category.inspect} for #{slug.inspect} is included in another category"
          )
        end
      end
    end
  end
end
