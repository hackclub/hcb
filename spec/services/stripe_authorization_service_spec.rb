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
        Set.new(["FAWRA*"]).freeze
      )
    end

    it "matches a merchant name starting with a forbidden prefix" do
      expect(described_class.forbidden_merchant_name?("FAWRA*A1B2C3")).to be(true)
    end

    it "matches regardless of case or surrounding whitespace" do
      expect(described_class.forbidden_merchant_name?("  fawra*a1b2c3 ")).to be(true)
    end

    it "does not match when the prefix appears mid-name" do
      expect(described_class.forbidden_merchant_name?("NOT FAWRA*A1B2C3")).to be(false)
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
