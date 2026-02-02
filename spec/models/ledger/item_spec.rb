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

        item.reload
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

    describe "primary_ledger association" do
      it "can be created without a primary_ledger" do
        item = Ledger::Item.new(
          amount_cents: 1000,
          memo: "Test",
          date: Time.current
        )
        expect(item).to be_valid
        expect(item.primary_ledger).to be_nil
      end

      it "can have a primary_ledger when mapped" do
        item = create(:ledger_item, :with_primary_ledger)
        expect(item).to be_valid
        expect(item.primary_ledger).to be_present
      end

      it "primary_ledger is accessible through mapping" do
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

      # I can't think of a use case for this right now, but in theory there's
      # no reason why we can't support it. Potential use case might be admin
      # ledger audits that includes unmapped (to primary ledger) transactions
      it "can have only non-primary ledger mappings" do
        non_primary_ledger = ::Ledger.new(primary: false)
        non_primary_ledger.save(validate: false)

        item = Ledger::Item.new(
          amount_cents: 1000,
          memo: "Test",
          date: Time.current
        )
        item.save!

        Ledger::Mapping.create!(
          ledger: non_primary_ledger,
          ledger_item: item,
          on_primary_ledger: false
        )

        item.reload
        expect(item).to be_valid
        expect(item.primary_ledger).to be_nil
        expect(item.all_ledgers).to contain_exactly(non_primary_ledger)
      end
    end

    describe "one primary mapping constraint" do
      it "allows an item to have exactly one primary mapping" do
        primary_ledger = ::Ledger.new(primary: true, event: create(:event))
        primary_ledger.save(validate: false)

        item = Ledger::Item.new(
          amount_cents: 1000,
          memo: "Test",
          date: Time.current
        )
        item.save(validate: false)

        mapping = Ledger::Mapping.create!(
          ledger: primary_ledger,
          ledger_item: item,
          on_primary_ledger: true
        )

        item.reload
        expect(item.ledger_mappings.where(on_primary_ledger: true).count).to eq(1)
        expect(item.primary_mapping).to eq(mapping)
      end

      it "does not allow an item to have multiple primary mappings" do
        primary_ledger1 = ::Ledger.new(primary: true, event: create(:event))
        primary_ledger1.save(validate: false)

        primary_ledger2 = ::Ledger.new(primary: true, event: create(:event))
        primary_ledger2.save(validate: false)

        item = Ledger::Item.new(
          amount_cents: 1000,
          memo: "Test",
          date: Time.current
        )
        item.save(validate: false)

        # Create first primary mapping
        Ledger::Mapping.create!(
          ledger: primary_ledger1,
          ledger_item: item,
          on_primary_ledger: true
        )

        # Try to create second primary mapping - should fail
        mapping2 = Ledger::Mapping.new(
          ledger: primary_ledger2,
          ledger_item: item,
          on_primary_ledger: true
        )

        expect(mapping2).not_to be_valid
        expect(mapping2.errors[:ledger_item_id]).to include("is already mapped on a primary ledger")
      end

      it "allows an item to have one primary mapping and multiple non-primary mappings" do
        primary_ledger = ::Ledger.new(primary: true, event: create(:event))
        primary_ledger.save(validate: false)

        non_primary_ledger1 = ::Ledger.new(primary: false)
        non_primary_ledger1.save(validate: false)

        non_primary_ledger2 = ::Ledger.new(primary: false)
        non_primary_ledger2.save(validate: false)

        item = Ledger::Item.new(
          amount_cents: 1000,
          memo: "Test",
          date: Time.current
        )
        item.save(validate: false)

        # Create primary mapping
        primary_mapping = Ledger::Mapping.create!(
          ledger: primary_ledger,
          ledger_item: item,
          on_primary_ledger: true
        )

        # Create first non-primary mapping
        Ledger::Mapping.create!(
          ledger: non_primary_ledger1,
          ledger_item: item,
          on_primary_ledger: false
        )

        # Create second non-primary mapping
        Ledger::Mapping.create!(
          ledger: non_primary_ledger2,
          ledger_item: item,
          on_primary_ledger: false
        )

        item.reload
        expect(item.ledger_mappings.count).to eq(3)
        expect(item.ledger_mappings.where(on_primary_ledger: true).count).to eq(1)
        expect(item.ledger_mappings.where(on_primary_ledger: false).count).to eq(2)
        expect(item.primary_mapping).to eq(primary_mapping)
      end

      it "enforces one primary mapping at database level" do
        primary_ledger1 = ::Ledger.new(primary: true, event: create(:event))
        primary_ledger1.save(validate: false)

        primary_ledger2 = ::Ledger.new(primary: true, event: create(:event))
        primary_ledger2.save(validate: false)

        item = Ledger::Item.new(
          amount_cents: 1000,
          memo: "Test",
          date: Time.current
        )
        item.save(validate: false)

        # Create first primary mapping
        Ledger::Mapping.create!(
          ledger: primary_ledger1,
          ledger_item: item,
          on_primary_ledger: true
        )

        # Try to create second primary mapping with validation bypassed
        # Should fail at database level due to unique index
        expect {
          mapping2 = Ledger::Mapping.new(
            ledger: primary_ledger2,
            ledger_item: item,
            on_primary_ledger: true
          )
          mapping2.save(validate: false)
        }.to raise_error(ActiveRecord::RecordNotUnique)
      end
    end
  end

  describe "#map_to_ledger" do
    let(:item) do
      i = Ledger::Item.new(amount_cents: 1000, memo: "Test", date: Time.current)
      i.save(validate: false)
      i
    end

    it "returns nil when no event or card grant can be calculated" do
      expect(item.map_to_ledger).to be_nil
      expect(item.primary_ledger).to be_nil
    end

    context "when an event can be calculated" do
      it "creates a primary ledger and mapping for the event" do
        event = create(:event)
        allow(item).to receive(:calculate_card_grant).and_return(nil)
        allow(item).to receive(:calculate_event).and_return(event)

        item.map_to_ledger
        item.reload

        expect(item.primary_ledger).to be_present
        expect(item.primary_ledger.primary?).to be true
        expect(item.primary_ledger.event).to eq(event)
      end
    end

    context "when a card grant can be calculated" do
      it "creates a primary ledger and mapping for the card grant" do
        event = create(:event, :with_positive_balance)
        card_grant = create(:card_grant, event:)
        allow(item).to receive(:calculate_card_grant).and_return(card_grant)

        item.map_to_ledger
        item.reload

        expect(item.primary_ledger).to be_present
        expect(item.primary_ledger.primary?).to be true
        expect(item.primary_ledger.card_grant).to eq(card_grant)
      end
    end

    it "reuses an existing ledger for the same event" do
      event = create(:event)
      existing_ledger = Ledger.create!(primary: true, event:)

      allow(item).to receive(:calculate_card_grant).and_return(nil)
      allow(item).to receive(:calculate_event).and_return(event)

      item.map_to_ledger
      item.reload

      expect(item.primary_ledger).to eq(existing_ledger)
    end

    it "is idempotent" do
      event = create(:event)
      allow(item).to receive(:calculate_card_grant).and_return(nil)
      allow(item).to receive(:calculate_event).and_return(event)

      item.map_to_ledger
      expect { item.map_to_ledger }.not_to(change { Ledger::Mapping.count })
    end
  end

  describe "#calculate_amount_cents" do
    let(:item) do
      i = Ledger::Item.new(amount_cents: 0, memo: "Test", date: Time.current)
      i.save(validate: false)
      i
    end

    it "returns 0 when there are no transactions" do
      expect(item.calculate_amount_cents).to eq(0)
    end

    it "sums canonical transaction amounts" do
      create(:canonical_transaction, amount_cents: -500, ledger_item_id: item.id)
      create(:canonical_transaction, amount_cents: -300, ledger_item_id: item.id)

      expect(item.calculate_amount_cents).to eq(-800)
    end
  end

  describe "#write_amount_cents!" do
    it "updates amount_cents from calculate_amount_cents" do
      item = Ledger::Item.new(amount_cents: 999, memo: "Test", date: Time.current)
      item.save(validate: false)

      create(:canonical_transaction, amount_cents: -500, ledger_item_id: item.id)

      item.write_amount_cents!
      item.reload

      expect(item.amount_cents).to eq(-500)
    end
  end
end
