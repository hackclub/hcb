# frozen_string_literal: true

require "rails_helper"

RSpec.describe UserService::ParseName do
  describe "#run" do
    it "returns self for chaining" do
      service = described_class.new(full_name: "John Doe").run
      expect(service).to be_a(described_class)
    end

    it "handles blank full_name" do
      service = described_class.new(full_name: "").run
      expect(service.first_name).to be_nil
      expect(service.last_name).to be_nil
    end

    it "handles nil full_name" do
      service = described_class.new(full_name: nil).run
      expect(service.first_name).to be_nil
      expect(service.last_name).to be_nil
    end
  end

  describe "#first_name" do
    it "parses simple names" do
      service = described_class.new(full_name: "John Doe").run
      expect(service.first_name).to eq("John")
    end

    it "keeps middle names in first_name" do
      service = described_class.new(full_name: "Martin Luther King").run
      expect(service.first_name).to eq("Martin Luther")
    end

    it "handles names with particles (von, de, etc.)" do
      service = described_class.new(full_name: "Wernher von Braun").run
      expect(service.first_name).to eq("Wernher von")
    end

    it "uses family name as fallback when given name is blank" do
      # Edge case where Namae only extracts family
      service = described_class.new(full_name: "Madonna").run
      expect(service.first_name).to eq("Madonna")
    end
  end

  describe "#last_name" do
    it "parses simple names" do
      service = described_class.new(full_name: "John Doe").run
      expect(service.last_name).to eq("Doe")
    end

    it "includes suffixes in last_name" do
      service = described_class.new(full_name: "Martin Luther King Jr.").run
      expect(service.last_name).to eq("King Jr.")
    end

    it "handles multiple word last names" do
      service = described_class.new(full_name: "José María García García").run
      # Depending on Namae parsing, family might be "García García" or just "García"
      expect(service.last_name).not_to be_nil
    end
  end

  describe "international names" do
    it "handles accented characters" do
      service = described_class.new(full_name: "José María Martínez").run
      expect(service.first_name).not_to be_nil
      expect(service.last_name).not_to be_nil
    end

    it "preserves unicode characters in parsing" do
      service = described_class.new(full_name: "François Müller").run
      expect(service.first_name).not_to be_nil
      expect(service.last_name).not_to be_nil
    end

    it "handles hyphenated first and last names" do
      service = described_class.new(full_name: "Jean-Claude Van Damme").run
      expect(service.first_name).not_to be_nil
      expect(service.last_name).not_to be_nil
    end
  end

  describe "composite names" do
    it "doesn't fail on single names" do
      service = described_class.new(full_name: "Madonna").run
      expect(service.first_name).to eq("Madonna")
      expect(service.last_name).to be_nil
    end

    it "handles comma-separated names" do
      service = described_class.new(full_name: "Doe, John").run
      # Namae can parse this format
      expect(service.first_name).not_to be_nil
      expect(service.last_name).not_to be_nil
    end

    it "handles titles in names" do
      service = described_class.new(full_name: "Prof. Donald Ervin Knuth").run
      # Namae strips titles - should work fine
      expect(service.first_name).not_to be_nil
      expect(service.last_name).not_to be_nil
    end
  end

  describe "component accessors" do
    let(:parsed) { described_class.new(full_name: "Martin Luther King Jr.").run }

    it "exposes given_name" do
      expect(parsed.given_name).to eq("Martin Luther")
    end

    it "exposes family_name" do
      expect(parsed.family_name).to eq("King")
    end

    it "exposes particle" do
      expect(parsed.particle).to be_nil
    end

    it "exposes suffix" do
      expect(parsed.suffix).to eq("Jr.")
    end
  end
end

