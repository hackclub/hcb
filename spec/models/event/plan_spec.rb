# frozen_string_literal: true

require "rails_helper"

RSpec.describe Event::Plan, type: :model do
  describe "#forces_transparency?" do
    it "is false by default" do
      expect(Event::Plan::Standard.new.forces_transparency?).to eq(false)
    end

    it "is true for the 2025 and 2026 Argosy plans" do
      expect(Event::Plan::Argosy2025.new.forces_transparency?).to eq(true)
      expect(Event::Plan::Argosy2026.new.forces_transparency?).to eq(true)
    end

    it "is true for plans inheriting from an Argosy plan" do
      expect(Event::Plan::ArgosyFtcSim2025.new.forces_transparency?).to eq(true)
    end

    it "is false for the 2024 Argosy plan" do
      expect(Event::Plan::Argosy2024.new.forces_transparency?).to eq(false)
    end
  end
end
