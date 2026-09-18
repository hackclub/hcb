# frozen_string_literal: true

require "rails_helper"

RSpec.shared_examples "has grant restrictions" do
  describe "merchant list conflict validation" do
    it "is valid when merchant_lock and banned_merchants are disjoint" do
      subject.merchant_lock = ["merchant_a"]
      subject.banned_merchants = ["merchant_b"]
      subject.valid?
      expect(subject.errors[:base]).to be_empty
    end

    it "is invalid when a merchant appears in both merchant_lock and banned_merchants" do
      subject.merchant_lock = ["merchant_a", "merchant_b"]
      subject.banned_merchants = ["merchant_b"]
      subject.valid?
      expect(subject.errors[:base]).to include(match(/merchant_b.*cannot be both allowed and blocked/i))
    end

    it "lists all conflicting merchants in the error message" do
      subject.merchant_lock = ["merchant_a", "merchant_b"]
      subject.banned_merchants = ["merchant_a", "merchant_b"]
      subject.valid?
      error = subject.errors[:base].join
      expect(error).to include("merchant_a").and include("merchant_b")
    end

    it "is valid when both merchant lists are empty" do
      subject.merchant_lock = []
      subject.banned_merchants = []
      subject.valid?
      expect(subject.errors[:base]).to be_empty
    end
  end

  describe "category list conflict validation" do
    it "is valid when category_lock and banned_categories are disjoint" do
      subject.category_lock = ["food"]
      subject.banned_categories = ["electronics"]
      subject.valid?
      expect(subject.errors[:base]).to be_empty
    end

    it "is invalid when a category appears in both category_lock and banned_categories" do
      subject.category_lock = ["food", "clothing"]
      subject.banned_categories = ["food"]
      subject.valid?
      expect(subject.errors[:base]).to include(match(/food.*cannot be both allowed and blocked/i))
    end

    it "uses singular 'Category' in the error message for a single conflict" do
      subject.category_lock = ["food"]
      subject.banned_categories = ["food"]
      subject.valid?
      expect(subject.errors[:base].join).to start_with("Category ")
    end

    it "uses plural 'Categories' in the error message for multiple conflicts" do
      subject.category_lock = ["food", "clothing"]
      subject.banned_categories = ["food", "clothing"]
      subject.valid?
      expect(subject.errors[:base].join).to start_with("Categories ")
    end
  end

  describe "combined conflicts" do
    it "reports both merchant and category errors when both lists conflict" do
      subject.merchant_lock = ["merchant_a"]
      subject.banned_merchants = ["merchant_a"]
      subject.category_lock = ["food"]
      subject.banned_categories = ["food"]
      subject.valid?
      errors = subject.errors[:base]
      expect(errors).to include(match(/merchant_a/i))
      expect(errors).to include(match(/food/i))
    end
  end
end

RSpec.describe HasGrantRestrictions do
  describe "included in CardGrant" do
    subject do
      build_stubbed(:card_grant,
                    merchant_lock: [],
                    banned_merchants: [],
                    category_lock: [],
                    banned_categories: [])
    end

    it_behaves_like "has grant restrictions"

    it "is invalid when a merchant allowed on the grant is blocked by the setting" do
      grant_setting = build_stubbed(:card_grant_setting,
                                    merchant_lock: [],
                                    banned_merchants: ["merchant_a"],
                                    category_lock: [],
                                    banned_categories: [])
      grant = build_stubbed(:card_grant,
                            merchant_lock: ["merchant_a"],
                            banned_merchants: [],
                            category_lock: [],
                            banned_categories: [])
      allow(grant).to receive(:setting).and_return(grant_setting)
      grant.valid?
      expect(grant.errors[:base]).to include(match(/merchant_a.*cannot be both allowed and blocked/i))
    end

    it "is invalid when a category allowed on the grant is blocked by the setting" do
      grant_setting = build_stubbed(:card_grant_setting,
                                    merchant_lock: [],
                                    banned_merchants: [],
                                    category_lock: [],
                                    banned_categories: ["food"])
      grant = build_stubbed(:card_grant,
                            merchant_lock: [],
                            banned_merchants: [],
                            category_lock: ["food"],
                            banned_categories: [])
      allow(grant).to receive(:setting).and_return(grant_setting)
      grant.valid?
      expect(grant.errors[:base]).to include(match(/food.*cannot be both allowed and blocked/i))
    end
  end

  describe "included in CardGrantSetting" do
    subject do
      CardGrantSetting.new(
        merchant_lock: [],
        banned_merchants: [],
        category_lock: [],
        banned_categories: []
      )
    end

    it_behaves_like "has grant restrictions"
  end
end
