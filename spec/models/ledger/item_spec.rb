# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ledger::Item, type: :model do
  describe "associations" do
    it "has many ledger_mappings" do
      item = Ledger::Item.new
      expect(item).to respond_to(:ledger_mappings)
    end

    it "has one primary_mapping" do
      item = Ledger::Item.new
      expect(item).to respond_to(:primary_mapping)
    end

    it "has one primary_ledger through primary_mapping" do
      item = Ledger::Item.new
      expect(item).to respond_to(:primary_ledger)
    end

    describe "primary_ledger association" do
      let(:primary_ledger) do
        l = ::Ledger.new(primary: true, event: create(:event))
        l.save(validate: false)
        l
      end
      let(:non_primary_ledger) do
        l = ::Ledger.new(primary: false)
        l.save(validate: false)
        l
      end

      it "returns the ledger from the primary mapping" do
        item = Ledger::Item.new(
          amount_cents: 1000,
          memo: "Test",
          date: Time.current
        )
        item.save(validate: false)

        Ledger::Mapping.create!(
          ledger: primary_ledger,
          ledger_item: item,
          on_primary_ledger: true
        )

        expect(item.primary_ledger).to eq(primary_ledger)
      end

      it "returns nil when no primary mapping exists" do
        item = Ledger::Item.new(
          amount_cents: 1000,
          memo: "Test",
          date: Time.current
        )
        item.save(validate: false)

        Ledger::Mapping.create!(
          ledger: non_primary_ledger,
          ledger_item: item,
          on_primary_ledger: false
        )

        expect(item.primary_ledger).to be_nil
      end

      it "only returns the primary ledger, not non-primary ledgers" do
        item = Ledger::Item.new(
          amount_cents: 1000,
          memo: "Test",
          date: Time.current
        )
        item.save(validate: false)

        Ledger::Mapping.create!(
          ledger: primary_ledger,
          ledger_item: item,
          on_primary_ledger: true
        )
        Ledger::Mapping.create!(
          ledger: non_primary_ledger,
          ledger_item: item,
          on_primary_ledger: false
        )

        expect(item.primary_ledger).to eq(primary_ledger)
      end
    end
  end

  describe "validations" do
    it "requires amount_cents" do
      item = Ledger::Item.new(memo: "Test", date: Time.current)
      expect(item).not_to be_valid
      expect(item.errors[:amount_cents]).to include("can't be blank")
    end

    it "requires memo" do
      item = Ledger::Item.new(amount_cents: 1000, date: Time.current)
      expect(item).not_to be_valid
      expect(item.errors[:memo]).to include("can't be blank")
    end

    it "requires date" do
      item = Ledger::Item.new(amount_cents: 1000, memo: "Test")
      expect(item).not_to be_valid
      expect(item.errors[:date]).to include("can't be blank")
    end

    describe "primary_ledger validation" do
      it "requires a primary_ledger" do
        item = Ledger::Item.new(
          amount_cents: 1000,
          memo: "Test",
          date: Time.current
        )
        # No primary mapping created
        expect(item).not_to be_valid
        expect(item.errors[:primary_ledger]).to include("can't be blank")
      end

      it "is valid when primary_ledger is present" do
        item = create(:ledger_item)
        expect(item).to be_valid
        expect(item.primary_ledger).to be_present
      end

      it "is valid when explicitly given a primary_ledger through mapping" do
        primary_ledger = ::Ledger.new(primary: true, event: create(:event))
        primary_ledger.save(validate: false)

        item = Ledger::Item.new(
          amount_cents: 1000,
          memo: "Test",
          date: Time.current
        )
        item.save(validate: false)

        Ledger::Mapping.create!(
          ledger: primary_ledger,
          ledger_item: item,
          on_primary_ledger: true
        )

        item.reload
        expect(item).to be_valid
        expect(item.primary_ledger).to eq(primary_ledger)
      end

      it "is not valid with only non-primary ledger mappings" do
        non_primary_ledger = ::Ledger.new(primary: false)
        non_primary_ledger.save(validate: false)

        item = Ledger::Item.new(
          amount_cents: 1000,
          memo: "Test",
          date: Time.current
        )
        item.save(validate: false)

        Ledger::Mapping.create!(
          ledger: non_primary_ledger,
          ledger_item: item,
          on_primary_ledger: false
        )

        item.reload
        expect(item).not_to be_valid
        expect(item.errors[:primary_ledger]).to include("can't be blank")
      end
    end
  end
end
