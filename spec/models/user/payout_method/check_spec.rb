# frozen_string_literal: true

require "rails_helper"

RSpec.describe User::PayoutMethod::Check do
  describe "address lines" do
    it "validates that address lines 1 and 2 don't exceed a combined 50 chars" do
      instance = described_class.new
      instance.validate
      expect(instance.errors[:base]).to be_empty

      instance.address_line1 = "a" * 51
      instance.validate
      expect(instance.errors[:base]).to eq(["Address line one and line two's combined length can not exceed 50 characters."])

      instance.address_line1 = "a" * 25
      instance.address_line2 = "b" * 26
      instance.validate
      expect(instance.errors[:base]).to eq(["Address line one and line two's combined length can not exceed 50 characters."])
    end
  end
end
