# frozen_string_literal: true

require "rails_helper"

RSpec.describe IllegalEntity, type: :model do
  let(:legal_entity) { create(:legal_entity) }

  def build_ach
    IllegalEntity::PayoutMethod::AchTransfer.create!(account_number: "12345678", routing_number: "021000021")
  end

  def build_check
    IllegalEntity::PayoutMethod::Check.create!(
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
end
