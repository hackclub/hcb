# frozen_string_literal: true

require "rails_helper"

RSpec.describe Event::Affiliation, type: :model do
  describe "Destination Imagination" do
    def build_affiliation(level: "elementary", team_number: "125-12345", size: 5)
      described_class.new(name: "destination_imagination", affiliable: build(:event), level:, team_number:, size:)
    end

    it "is valid with a level, team number, and size" do
      expect(build_affiliation).to be_valid
    end

    it "is a Destination Imagination affiliation" do
      affiliation = build_affiliation

      expect(affiliation.is_destination_imagination?).to be(true)
      expect(affiliation.is_first?).to be(false)
      expect(affiliation.is_vex?).to be(false)
      expect(affiliation.is_hack_club?).to be(false)
    end

    %i[level team_number size].each do |field|
      it "requires #{field}" do
        affiliation = build_affiliation(field => nil)

        expect(affiliation).not_to be_valid
        expect(affiliation.errors[:metadata]).to include("is missing fields: #{field}")
      end
    end

    it "rejects a level that isn't one of Destination Imagination's levels" do
      affiliation = build_affiliation(level: "high_school")

      expect(affiliation).not_to be_valid
      expect(affiliation.errors[:level]).to be_present
    end

    it "accepts every Destination Imagination level" do
      described_class::DESTINATION_IMAGINATION_LEVELS.each_key do |level|
        expect(build_affiliation(level:)).to be_valid
      end
    end

    describe "#display_name" do
      it "is Destination Imagination" do
        expect(build_affiliation.display_name).to eq("Destination Imagination")
      end
    end

    describe "#to_s" do
      it "includes the level's name, team number, and size" do
        expect(build_affiliation.to_s).to eq("Destination Imagination – Elementary – 125-12345 – 5 people")
      end

      it "renders multi-word levels by name rather than by value" do
        affiliation = build_affiliation(level: "early_learning")

        expect(affiliation.to_s).to eq("Destination Imagination – Early Learning – 125-12345 – 5 people")
      end
    end
  end
end
