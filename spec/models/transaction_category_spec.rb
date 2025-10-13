# frozen_string_literal: true

require "rails_helper"

RSpec.describe TransactionCategory do
  describe "slug" do
    it "must be present" do
      instance = described_class.new(slug: "")
      instance.validate
      expect(instance.errors[:slug]).to include("can't be blank")
    end

    it "must be unique" do
      _existing = described_class.create!(slug: "rent")

      instance = described_class.new(slug: "rent")
      instance.validate
      expect(instance.errors[:slug]).to include("has already been taken")
    end

    it "must be part of the list" do
      instance = described_class.new(slug: "energy-drinks")
      instance.validate
      expect(instance.errors[:slug]).to include("is not included in the list")
    end
  end
end
