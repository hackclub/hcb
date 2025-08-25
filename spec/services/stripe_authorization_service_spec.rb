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
end
