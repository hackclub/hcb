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
        ledger_item: create(:ledger_item),
        on_primary_ledger: false
        # Note: No mapped_by set
      )

      expect(mapping).to be_valid
      expect(mapping.mapped_by).to be_nil
    end
  end

  describe "on_primary_ledger matches ledger.primary" do
    let(:user) { create(:user) }
    let(:ledger_item) { create(:ledger_item) }

    context "when on_primary_ledger is true" do
      it "is valid if ledger.primary is true" do
        ledger = create(:event).ledger

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
        ledger = create(:event).ledger

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

  describe "ledger_item uniqueness per ledger" do
    let(:user) { create(:user) }
    let!(:primary_ledger) do
      create(:event).ledger
    end
    let!(:non_primary_ledger) do
      l = ::Ledger.new(primary: false)
      l.save(validate: false)
      l
    end
    let!(:ledger_item) { create(:ledger_item) }

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
        expect(mapping2.errors[:ledger_item_id]).to include("is already mapped on a primary ledger")
      end
    end

    context "when on_primary_ledger is false" do
      it "does not allow multiple mappings of same ledger_item to the same ledger" do
        # Create first mapping on non-primary
        Ledger::Mapping.create!(
          ledger: non_primary_ledger,
          ledger_item: ledger_item,
          on_primary_ledger: false,
          mapped_by: user
        )

        # Try to create second mapping with same ledger_item to the same ledger
        mapping2 = Ledger::Mapping.new(
          ledger: non_primary_ledger,
          ledger_item: ledger_item,
          on_primary_ledger: false,
          mapped_by: user
        )

        expect(mapping2).not_to be_valid
        expect(mapping2.errors[:ledger_item_id]).to include("is already mapped to this ledger")
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
      create(:event).ledger
    end
    let!(:non_primary_ledger) do
      l = ::Ledger.new(primary: false)
      l.save(validate: false)
      l
    end
    let!(:ledger_item) { create(:ledger_item) }

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

    it "enforces uniqueness per ledger at database level" do
      # Create first mapping on non-primary
      Ledger::Mapping.create!(
        ledger: non_primary_ledger,
        ledger_item: ledger_item,
        on_primary_ledger: false,
        mapped_by: user
      )

      # Try to create duplicate with validation bypassed - should fail at DB level
      expect {
        mapping2 = Ledger::Mapping.new(
          ledger: non_primary_ledger,
          ledger_item: ledger_item,
          on_primary_ledger: false,
          mapped_by: user
        )
        mapping2.save(validate: false)
      }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "enforces on_primary_ledger matches ledger.primary at database level" do
      # Try to create mapping with mismatched on_primary_ledger
      expect {
        mapping = Ledger::Mapping.new(
          ledger: primary_ledger,
          ledger_item: create(:ledger_item),
          on_primary_ledger: false # Mismatch! ledger.primary is true
        )
        mapping.save(validate: false) # Bypass application validation
      }.to raise_error(ActiveRecord::InvalidForeignKey)
    end

    it "enforces on_primary_ledger matches ledger.primary (inverse case)" do
      # Try to create mapping with mismatched on_primary_ledger (opposite direction)
      expect {
        mapping = Ledger::Mapping.new(
          ledger: non_primary_ledger,
          ledger_item: create(:ledger_item),
          on_primary_ledger: true # Mismatch! ledger.primary is false
        )
        mapping.save(validate: false) # Bypass application validation
      }.to raise_error(ActiveRecord::InvalidForeignKey)
    end
  end

  describe ".map_primary!" do
    let(:user) { create(:user) }
    let(:ledger_item) { create(:ledger_item) }
    let(:primary_ledger) { create(:event).ledger }

    it "creates a primary mapping when none exists" do
      mapping = nil
      expect {
        mapping = Ledger::Mapping.map_primary!(ledger: primary_ledger, ledger_item:, mapped_by: user)
      }.to change { Ledger::Mapping.count }.by(1)

      expect(mapping).to be_persisted
      expect(mapping.on_primary_ledger).to be true
      expect(mapping.ledger).to eq(primary_ledger)
      expect(mapping.mapped_by).to eq(user)
    end

    it "stores no mapped_by when mapped by the system" do
      mapping = Ledger::Mapping.map_primary!(ledger: primary_ledger, ledger_item:, mapped_by: Ledger::Mapper::SYSTEM)

      expect(mapping.mapped_by).to be_nil
      expect(mapping.mapped_by_human?).to be false
    end

    it "raises when mapped_by is nil" do
      expect {
        Ledger::Mapping.map_primary!(ledger: primary_ledger, ledger_item:, mapped_by: nil)
      }.to raise_error(ArgumentError)
    end

    it "reuses the existing primary mapping when remapping to another ledger" do
      original = Ledger::Mapping.map_primary!(ledger: primary_ledger, ledger_item:, mapped_by: user)

      other_ledger = create(:event).ledger
      remapped = nil
      expect {
        remapped = Ledger::Mapping.map_primary!(ledger: other_ledger, ledger_item:, mapped_by: user)
      }.not_to(change { Ledger::Mapping.count })

      expect(remapped.id).to eq(original.id)
      expect(remapped.ledger).to eq(other_ledger)
    end

    it "does not reuse an existing non-primary mapping for the same item" do
      non_primary_ledger = create(:ledger)
      non_primary = Ledger::Mapping.map_non_primary!(ledger: non_primary_ledger, ledger_item:, mapped_by: user)

      mapping = nil
      expect {
        mapping = Ledger::Mapping.map_primary!(ledger: primary_ledger, ledger_item:, mapped_by: user)
      }.to change { Ledger::Mapping.count }.by(1)

      expect(mapping.id).not_to eq(non_primary.id)
      non_primary.reload
      expect(non_primary.on_primary_ledger).to be false
      expect(non_primary.ledger).to eq(non_primary_ledger)
    end

    it "refuses to map onto a non-primary ledger" do
      expect {
        Ledger::Mapping.map_primary!(ledger: create(:ledger), ledger_item:, mapped_by: user)
      }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  describe ".map_non_primary!" do
    let(:user) { create(:user) }
    let(:ledger_item) { create(:ledger_item) }
    let(:non_primary_ledger) { create(:ledger) }

    it "creates a non-primary mapping" do
      mapping = nil
      expect {
        mapping = Ledger::Mapping.map_non_primary!(ledger: non_primary_ledger, ledger_item:, mapped_by: user)
      }.to change { Ledger::Mapping.count }.by(1)

      expect(mapping).to be_persisted
      expect(mapping.on_primary_ledger).to be false
      expect(mapping.ledger).to eq(non_primary_ledger)
      expect(mapping.mapped_by).to eq(user)
    end

    it "stores no mapped_by when mapped by the system" do
      mapping = Ledger::Mapping.map_non_primary!(ledger: non_primary_ledger, ledger_item:, mapped_by: Ledger::Mapper::SYSTEM)

      expect(mapping.mapped_by).to be_nil
    end

    it "raises when mapped_by is nil" do
      expect {
        Ledger::Mapping.map_non_primary!(ledger: non_primary_ledger, ledger_item:, mapped_by: nil)
      }.to raise_error(ArgumentError)
    end

    it "is idempotent" do
      original = Ledger::Mapping.map_non_primary!(ledger: non_primary_ledger, ledger_item:, mapped_by: user)

      repeated = nil
      expect {
        repeated = Ledger::Mapping.map_non_primary!(ledger: non_primary_ledger, ledger_item:, mapped_by: user)
      }.not_to(change { Ledger::Mapping.count })

      expect(repeated.id).to eq(original.id)
    end

    it "does not reuse or modify the item's primary mapping" do
      primary_ledger = create(:event).ledger
      primary = Ledger::Mapping.map_primary!(ledger: primary_ledger, ledger_item:, mapped_by: user)

      mapping = nil
      expect {
        mapping = Ledger::Mapping.map_non_primary!(ledger: non_primary_ledger, ledger_item:, mapped_by: user)
      }.to change { Ledger::Mapping.count }.by(1)

      expect(mapping.id).not_to eq(primary.id)
      primary.reload
      expect(primary.on_primary_ledger).to be true
      expect(primary.ledger).to eq(primary_ledger)
    end

    it "refuses to map onto a primary ledger" do
      primary_ledger = create(:event).ledger

      expect {
        Ledger::Mapping.map_non_primary!(ledger: primary_ledger, ledger_item:, mapped_by: user)
      }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  describe "mapped_by scopes" do
    let(:user) { create(:user) }

    it "separates human and system mappings" do
      human = Ledger::Mapping.map_primary!(ledger: create(:event).ledger, ledger_item: create(:ledger_item), mapped_by: user)
      system = Ledger::Mapping.map_primary!(ledger: create(:event).ledger, ledger_item: create(:ledger_item), mapped_by: Ledger::Mapper::SYSTEM)

      expect(Ledger::Mapping.mapped_by_human).to contain_exactly(human)
      expect(Ledger::Mapping.mapped_by_system).to contain_exactly(system)
    end
  end
end
