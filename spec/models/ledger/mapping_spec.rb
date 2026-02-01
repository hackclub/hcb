# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ledger::Mapping, type: :model do
  describe "associations" do
    it "belongs to ledger" do
      mapping = Ledger::Mapping.new
      expect(mapping).to respond_to(:ledger)
    end

    it "belongs to ledger_item" do
      mapping = Ledger::Mapping.new
      expect(mapping).to respond_to(:ledger_item)
    end

    it "belongs to mapped_by" do
      mapping = Ledger::Mapping.new
      expect(mapping).to respond_to(:mapped_by)
    end

    it "mapped_by is optional" do
      ledger = ::Ledger.new(primary: false)
      ledger.save(validate: false)

      mapping = Ledger::Mapping.new(
        ledger: ledger,
        ledger_item: create(:ledger_item, :without_primary_ledger),
        on_primary_ledger: false
        # Note: No mapped_by set
      )

      expect(mapping).to be_valid
      expect(mapping.mapped_by).to be_nil
    end
  end

  describe "on_primary_ledger matches ledger.primary" do
    let(:user) { create(:user) }
    let(:ledger_item) { create(:ledger_item, :without_primary_ledger) }

    context "when on_primary_ledger is true" do
      it "is valid if ledger.primary is true" do
        ledger = ::Ledger.new(primary: true, event: create(:event))
        ledger.save(validate: false)

        mapping = Ledger::Mapping.new(
          ledger: ledger,
          ledger_item: ledger_item,
          on_primary_ledger: true,
          mapped_by: user
        )
        expect(mapping).to be_valid
      end

      it "is not valid if ledger.primary is false" do
        ledger = ::Ledger.new(primary: false)
        ledger.save(validate: false)

        mapping = Ledger::Mapping.new(
          ledger: ledger,
          ledger_item: ledger_item,
          on_primary_ledger: true,
          mapped_by: user
        )
        expect(mapping).not_to be_valid
        expect(mapping.errors[:on_primary_ledger]).to include("must match ledger's primary status")
      end
    end

    context "when on_primary_ledger is false" do
      it "is valid if ledger.primary is false" do
        ledger = ::Ledger.new(primary: false)
        ledger.save(validate: false)

        mapping = Ledger::Mapping.new(
          ledger: ledger,
          ledger_item: ledger_item,
          on_primary_ledger: false,
          mapped_by: user
        )
        expect(mapping).to be_valid
      end

      it "is not valid if ledger.primary is true" do
        ledger = ::Ledger.new(primary: true, event: create(:event))
        ledger.save(validate: false)

        mapping = Ledger::Mapping.new(
          ledger: ledger,
          ledger_item: ledger_item,
          on_primary_ledger: false,
          mapped_by: user
        )
        expect(mapping).not_to be_valid
        expect(mapping.errors[:on_primary_ledger]).to include("must match ledger's primary status")
      end
    end
  end

  describe "ledger_item uniqueness on primary ledger" do
    let(:user) { create(:user) }
    let!(:primary_ledger) do
      l = ::Ledger.new(primary: true, event: create(:event))
      l.save(validate: false)
      l
    end
    let!(:non_primary_ledger) do
      l = ::Ledger.new(primary: false)
      l.save(validate: false)
      l
    end
    let!(:ledger_item) { create(:ledger_item, :without_primary_ledger) }

    context "when on_primary_ledger is true" do
      it "allows first mapping of a ledger_item on primary ledger" do
        mapping = Ledger::Mapping.new(
          ledger: primary_ledger,
          ledger_item: ledger_item,
          on_primary_ledger: true,
          mapped_by: user
        )
        expect(mapping).to be_valid
      end

      it "does not allow duplicate ledger_item_id on primary ledger" do
        # Create first mapping
        Ledger::Mapping.create!(
          ledger: primary_ledger,
          ledger_item: ledger_item,
          on_primary_ledger: true,
          mapped_by: user
        )

        # Try to create second mapping with same ledger_item on primary
        mapping2 = Ledger::Mapping.new(
          ledger: primary_ledger,
          ledger_item: ledger_item,
          on_primary_ledger: true,
          mapped_by: user
        )

        expect(mapping2).not_to be_valid
        expect(mapping2.errors[:ledger_item]).to include("is already mapped on a primary ledger")
      end
    end

    context "when on_primary_ledger is false" do
      it "allows multiple mappings of same ledger_item on non-primary ledgers" do
        # Create first mapping on non-primary
        Ledger::Mapping.create!(
          ledger: non_primary_ledger,
          ledger_item: ledger_item,
          on_primary_ledger: false,
          mapped_by: user
        )

        # Create second mapping with same ledger_item on non-primary
        mapping2 = Ledger::Mapping.new(
          ledger: non_primary_ledger,
          ledger_item: ledger_item,
          on_primary_ledger: false,
          mapped_by: user
        )

        expect(mapping2).to be_valid
      end

      it "allows mapping on non-primary even if already mapped on primary" do
        # Create mapping on primary
        Ledger::Mapping.create!(
          ledger: primary_ledger,
          ledger_item: ledger_item,
          on_primary_ledger: true,
          mapped_by: user
        )

        # Create mapping on non-primary with same ledger_item
        mapping2 = Ledger::Mapping.new(
          ledger: non_primary_ledger,
          ledger_item: ledger_item,
          on_primary_ledger: false,
          mapped_by: user
        )

        expect(mapping2).to be_valid
      end
    end
  end

  describe "database constraint" do
    let(:user) { create(:user) }
    let!(:primary_ledger) do
      l = ::Ledger.new(primary: true, event: create(:event))
      l.save(validate: false)
      l
    end
    let!(:non_primary_ledger) do
      l = ::Ledger.new(primary: false)
      l.save(validate: false)
      l
    end
    let!(:ledger_item) { create(:ledger_item, :without_primary_ledger) }

    it "enforces uniqueness at database level for primary ledger mappings" do
      # Create first mapping
      Ledger::Mapping.create!(
        ledger: primary_ledger,
        ledger_item: ledger_item,
        on_primary_ledger: true,
        mapped_by: user
      )

      # Try to create duplicate with validation bypassed
      expect {
        mapping2 = Ledger::Mapping.new(
          ledger: primary_ledger,
          ledger_item: ledger_item,
          on_primary_ledger: true,
          mapped_by: user
        )
        mapping2.save(validate: false)
      }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "allows duplicate ledger_item_id when on_primary_ledger is false" do
      # Create first mapping on non-primary
      Ledger::Mapping.create!(
        ledger: non_primary_ledger,
        ledger_item: ledger_item,
        on_primary_ledger: false,
        mapped_by: user
      )

      # Create second mapping - should succeed
      expect {
        mapping2 = Ledger::Mapping.new(
          ledger: non_primary_ledger,
          ledger_item: ledger_item,
          on_primary_ledger: false,
          mapped_by: user
        )
        mapping2.save(validate: false)
      }.not_to raise_error
    end

    it "enforces on_primary_ledger matches ledger.primary at database level" do
      # Try to create mapping with mismatched on_primary_ledger
      expect {
        mapping = Ledger::Mapping.new(
          ledger: primary_ledger,
          ledger_item: create(:ledger_item, :without_primary_ledger),
          on_primary_ledger: false  # Mismatch! ledger.primary is true
        )
        mapping.save(validate: false)  # Bypass application validation
      }.to raise_error(ActiveRecord::InvalidForeignKey)
    end

    it "enforces on_primary_ledger matches ledger.primary (inverse case)" do
      # Try to create mapping with mismatched on_primary_ledger (opposite direction)
      expect {
        mapping = Ledger::Mapping.new(
          ledger: non_primary_ledger,
          ledger_item: create(:ledger_item, :without_primary_ledger),
          on_primary_ledger: true  # Mismatch! ledger.primary is false
        )
        mapping.save(validate: false)  # Bypass application validation
      }.to raise_error(ActiveRecord::InvalidForeignKey)
    end
  end
end
