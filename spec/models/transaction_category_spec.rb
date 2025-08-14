# frozen_string_literal: true

require "rails_helper"

RSpec.describe TransactionCategory do
  describe "name" do
    it "must be present" do
      instance = described_class.new(name: "")
      instance.validate
      expect(instance.errors[:name]).to include("can't be blank")
    end

    it "must be unique" do
      _existing = described_class.create!(name: "Donations")

      instance = described_class.new(name: "Donations")
      instance.validate
      expect(instance.errors[:name]).to include("has already been taken")
    end

    it "must be part of the list" do
      instance = described_class.new(name: "Energy Drinks")
      instance.validate
      expect(instance.errors[:name]).to include("is not included in the list")
    end
  end
end
