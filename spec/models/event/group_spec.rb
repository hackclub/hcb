# frozen_string_literal: true

require "rails_helper"

RSpec.describe Event::Group do
  describe "#name" do
    it "must be unique" do
      user = create(:user)
      _existing = described_class.create!(user:, name: "Scrapyard")

      instance = described_class.new(user:, name: "Scrapyard")
      instance.validate
      expect(instance.errors[:name]).to eq(["has already been taken"])

      instance.name = "scrapYard"
      instance.validate
      expect(instance.errors[:name]).to eq(["has already been taken"])

      expect do
        described_class.insert!({ user_id: user.id, name: "Scrapyard" })
      end.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "must be present" do
      instance = described_class.new(name: "")
      instance.validate
      expect(instance.errors[:name]).to eq(["can't be blank"])
    end
  end
end
