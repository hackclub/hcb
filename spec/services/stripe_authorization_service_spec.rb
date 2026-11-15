# frozen_string_literal: true

require "rails_helper"

RSpec.describe StripeAuthorizationService do
  describe "FORBIDDEN_MERCHANT_CATEGORIES" do
    it "contains a list of valid merchant categories" do
      described_class::FORBIDDEN_MERCHANT_CATEGORIES.each do |merchant_category|
        expect(YellowPages::Category.categories_by_key.fetch(merchant_category)).to be_present
      end
    end
  end

  describe ".forbidden_merchant_name?" do
    before do
      stub_const(
        "StripeAuthorizationService::FORBIDDEN_MERCHANT_NAME_PREFIXES",
        Set.new(["FAWRY", "MYFAWRY"]).freeze
      )
    end

    it "matches a merchant name starting with a forbidden prefix" do
      expect(described_class.forbidden_merchant_name?("FAWRY*A1B2C3")).to be(true)
    end

    it "matches other descriptors sharing a forbidden prefix" do
      expect(described_class.forbidden_merchant_name?("FAWRYPF*A1B2C3")).to be(true)
      expect(described_class.forbidden_merchant_name?("FAWRY PAY")).to be(true)
    end

    it "matches any of the forbidden prefixes" do
      expect(described_class.forbidden_merchant_name?("MYFAWRY TOP UP")).to be(true)
    end

    it "matches regardless of case or surrounding whitespace" do
      expect(described_class.forbidden_merchant_name?("  fawry*a1b2c3 ")).to be(true)
    end

    it "does not match when the prefix appears mid-name" do
      expect(described_class.forbidden_merchant_name?("NOT FAWRY*A1B2C3")).to be(false)
    end

    it "does not match an unrelated merchant" do
      expect(described_class.forbidden_merchant_name?("HCB-TEST")).to be(false)
    end

    it "does not match a blank name" do
      expect(described_class.forbidden_merchant_name?(nil)).to be(false)
      expect(described_class.forbidden_merchant_name?("  ")).to be(false)
    end
  end
end
