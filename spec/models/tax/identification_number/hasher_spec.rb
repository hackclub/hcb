# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tax::IdentificationNumber::Hasher, type: :model do
  let(:individual) { described_class::INDIVIDUAL }
  let(:entity) { described_class::ENTITY }
  let(:foreign) { described_class::FOREIGN }

  def hash_tin(tin, tin_type: individual, country: "US")
    described_class.hash_tin(tin, tin_type:, country:)
  end

  describe ".hash_tin" do
    it "returns nil for a TIN that is absent" do
      expect(hash_tin(nil)).to be_nil
      expect(hash_tin("")).to be_nil
      expect(hash_tin("   ")).to be_nil
      expect(hash_tin("---")).to be_nil
    end

    it "never returns the TIN it was given" do
      expect(hash_tin("123456789")).not_to include("123456789")
    end

    it "fingerprints the same taxpayer identically regardless of formatting" do
      expect(hash_tin("123-45-6789")).to eq(hash_tin("123456789"))
      expect(hash_tin(" 123 45 6789 ")).to eq(hash_tin("123456789"))
    end

    it "fingerprints different taxpayers differently" do
      expect(hash_tin("123456789")).not_to eq(hash_tin("987654321"))
    end

    it "separates an SSN from an EIN that shares the same digits" do
      expect(hash_tin("123456789", tin_type: individual))
        .not_to eq(hash_tin("123456789", tin_type: entity))
    end

    it "separates a US TIN from a foreign TIN that shares the same digits" do
      expect(hash_tin("123456789", tin_type: individual, country: "US"))
        .not_to eq(hash_tin("123456789", tin_type: foreign, country: "CA"))
    end

    it "separates foreign TINs issued by different countries" do
      expect(hash_tin("123456789", tin_type: foreign, country: "CA"))
        .not_to eq(hash_tin("123456789", tin_type: foreign, country: "GB"))
    end

    it "rejects a TIN it cannot namespace" do
      expect { described_class.hash_tin("123456789", tin_type: :nonsense, country: "US") }
        .to raise_error(described_class::HashingError)
      expect { described_class.hash_tin("123456789", tin_type: individual, country: "") }
        .to raise_error(described_class::HashingError)
    end

    it "does not leak the TIN through a raised error" do
      allow(described_class).to receive(:kms_key_id).and_raise("boom 123456789")

      expect { hash_tin("123456789") }.to raise_error(described_class::HashingError) do |error|
        expect(error.message).not_to include("123456789")
        expect(error.cause).to be_nil
      end
    end
  end

  describe ".tin_type_for" do
    it "maps a person to the individual TIN space and a business to the entity one" do
      expect(described_class.tin_type_for(entity_type: "person")).to eq(individual)
      expect(described_class.tin_type_for(entity_type: "business")).to eq(entity)
    end

    it "maps a foreign TIN to the foreign space regardless of entity type" do
      expect(described_class.tin_type_for(entity_type: "person", foreign: true)).to eq(foreign)
      expect(described_class.tin_type_for(entity_type: "business", foreign: true)).to eq(foreign)
    end
  end

  describe "key handling" do
    it "marks fingerprints made without KMS so they can never be mistaken for real ones" do
      expect(hash_tin("123456789")).to start_with("DEV_")
    end

    it "refuses to fingerprint a TIN in a deployed environment with no KMS key" do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("staging"))
      allow(described_class).to receive(:kms_key_id).and_return(nil)

      expect { hash_tin("123456789") }
        .to raise_error(described_class::HashingError, /KMS is not configured/)
    end
  end
end
