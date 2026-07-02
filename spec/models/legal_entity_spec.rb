# frozen_string_literal: true

require "rails_helper"

RSpec.describe LegalEntity, type: :model do
  let(:legal_entity) { create(:legal_entity) }

  def build_ach
    LegalEntity::PayoutMethod::AchTransfer.create!(account_number: "12345678", routing_number: "021000021")
  end

  def build_check
    LegalEntity::PayoutMethod::Check.create!(
      address_line1: "1 Main St",
      address_city: "New York",
      address_state: "NY",
      address_postal_code: "10001"
    )
  end

  describe "#payout_methods" do
    it "returns the entity's payout methods" do
      ach = legal_entity.payout_methods.create!(details: build_ach)
      check = legal_entity.payout_methods.create!(details: build_check)

      expect(legal_entity.payout_methods).to contain_exactly(ach, check)
    end
  end

  describe "#default_payout_method" do
    it "returns the payout method flagged as default" do
      legal_entity.payout_methods.create!(details: build_ach)
      default = legal_entity.payout_methods.create!(details: build_check, default: true)

      expect(legal_entity.default_payout_method).to eq(default)
    end

    it "returns nil when no default is set" do
      legal_entity.payout_methods.create!(details: build_ach)
      expect(legal_entity.default_payout_method).to be_nil
    end
  end

  describe "address_country" do
    it "is valid when blank" do
      expect(build(:legal_entity, address_country: nil)).to be_valid
    end

    it "accepts a recognized ISO 3166-1 alpha-2 code" do
      expect(build(:legal_entity, address_country: "CA")).to be_valid
    end

    it "rejects an unrecognized country code" do
      entity = build(:legal_entity, address_country: "ZZ")
      expect(entity).not_to be_valid
      expect(entity.errors[:address_country]).to be_present
    end

    it "normalizes a lowercase code to uppercase" do
      entity = build(:legal_entity, address_country: "us")
      entity.valid?
      expect(entity.address_country).to eq("US")
    end

    it "normalizes surrounding whitespace" do
      entity = build(:legal_entity, address_country: "  gb  ")
      entity.valid?
      expect(entity.address_country).to eq("GB")
    end

    it "normalizes a blank string to nil" do
      entity = build(:legal_entity, address_country: "   ")
      entity.valid?
      expect(entity.address_country).to be_nil
    end
  end
end
