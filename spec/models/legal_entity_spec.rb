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

  describe "#mismatched_tax_form" do
    let(:legal_entity) { create(:legal_entity, tin_hash: "abc") }

    it "returns a completed form whose TIN differs from the entity's" do
      other = create(:tax_form, :completed, legal_entity:, tin_hash: "def")

      expect(legal_entity.mismatched_tax_form).to eq(other)
    end

    it "ignores a form carrying the entity's own TIN" do
      create(:tax_form, :completed, legal_entity:, tin_hash: "abc")

      expect(legal_entity.mismatched_tax_form).to be_nil
    end

    it "ignores a form that has no TIN yet" do
      create(:tax_form, :sent, legal_entity:, tin_hash: nil)

      expect(legal_entity.mismatched_tax_form).to be_nil
    end

    it "ignores a completed form that never produced a TIN" do
      create(:tax_form, :completed, legal_entity:, tin_hash: nil)

      expect(legal_entity.mismatched_tax_form).to be_nil
    end

    it "ignores a discarded form" do
      create(:tax_form, :completed, legal_entity:, tin_hash: "def", aasm_state: :discarded)

      expect(legal_entity.mismatched_tax_form).to be_nil
    end

    it "returns nil when the entity has no TIN of its own to compare against" do
      entity = create(:legal_entity, tin_hash: nil)
      create(:tax_form, :completed, legal_entity: entity, tin_hash: "def")

      expect(entity.mismatched_tax_form).to be_nil
    end
  end

  describe "#payable?" do
    it "stays payable while a newly started tax form is still pending" do
      entity = create(:legal_entity, tin_hash: "abc")
      create(:tax_form, :completed, legal_entity: entity, tin_hash: "abc",
                                    taxbandits_tin_matching_status: :success)
      create(:tax_form, :sent, legal_entity: entity, tin_hash: nil)

      expect(entity.reload).to be_payable
    end

    it "is not payable once a completed form reports a different TIN" do
      entity = create(:legal_entity, tin_hash: "abc")
      create(:tax_form, :completed, legal_entity: entity, tin_hash: "abc",
                                    taxbandits_tin_matching_status: :success)
      create(:tax_form, :completed, legal_entity: entity, tin_hash: "def")

      expect(entity.reload).not_to be_payable
    end

    it "is not payable once archived" do
      entity = create(:legal_entity, tin_hash: "abc", archived_at: Time.current)
      create(:tax_form, :completed, legal_entity: entity, tin_hash: "abc",
                                    taxbandits_tin_matching_status: :success)

      expect(entity.reload).not_to be_payable
    end
  end

  describe "#completed_tax_form?" do
    it "stays true after a new tax form is started" do
      entity = create(:legal_entity, tin_hash: "abc")
      create(:tax_form, :completed, legal_entity: entity, tin_hash: "abc")
      # A pending form outranks the completed one in latest_tax_form (NULLS FIRST).
      create(:tax_form, :sent, legal_entity: entity, tin_hash: nil)

      expect(entity.completed_tax_form?).to be true
    end

    it "is false when no form has completed" do
      entity = create(:legal_entity)
      create(:tax_form, :sent, legal_entity: entity)

      expect(entity.completed_tax_form?).to be false
    end
  end

  describe "TIN immutability" do
    it "refuses to change a TIN once it is set" do
      entity = create(:legal_entity, tin_hash: "abc")

      entity.tin_hash = "def"

      expect(entity).not_to be_valid
      expect(entity.errors[:tin_hash]).to include("cannot change once set")
    end
  end
end
