# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ledger::Mapper do
  let(:item) do
    i = Ledger::Item.new(amount_cents: 1000, memo: "Test", datetime: Time.current)
    i.save(validate: false)
    i
  end

  subject(:mapper) { described_class.new(ledger_item: item) }

  describe "#run" do
    it "returns nil when no event or card grant can be calculated" do
      expect(mapper.run).to be_nil
      expect(item.primary_ledger).to be_nil
    end

    context "when an event can be calculated" do
      it "creates a primary ledger and mapping for the event" do
        event = create(:event)
        allow(mapper).to receive(:calculate_card_grant).and_return(nil)
        allow(mapper).to receive(:calculate_event).and_return(event)

        mapper.run
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
        allow(mapper).to receive(:calculate_card_grant).and_return(card_grant)

        mapper.run
        item.reload

        expect(item.primary_ledger).to be_present
        expect(item.primary_ledger.primary?).to be true
        expect(item.primary_ledger.card_grant).to eq(card_grant)
      end
    end

    it "reuses an existing ledger for the same event" do
      event = create(:event)
      existing_ledger = event.ledger # Event automatically creates a ledger

      allow(mapper).to receive(:calculate_card_grant).and_return(nil)
      allow(mapper).to receive(:calculate_event).and_return(event)

      mapper.run
      item.reload

      expect(item.primary_ledger).to eq(existing_ledger)
    end

    it "is idempotent" do
      event = create(:event)
      allow(mapper).to receive(:calculate_card_grant).and_return(nil)
      allow(mapper).to receive(:calculate_event).and_return(event)

      mapper.run
      expect { mapper.run }.not_to(change { Ledger::Mapping.count })
    end

    it "prefers a card grant over an event" do
      event = create(:event, :with_positive_balance)
      card_grant = create(:card_grant, event:)
      allow(mapper).to receive(:calculate_card_grant).and_return(card_grant)
      allow(mapper).to receive(:calculate_event).and_return(event)

      mapper.run
      item.reload

      expect(item.primary_ledger.card_grant).to eq(card_grant)
      expect(item.primary_ledger.event).to be_nil
    end

    it "records the mapping as made by the system" do
      event = create(:event)
      allow(mapper).to receive(:calculate_card_grant).and_return(nil)
      allow(mapper).to receive(:calculate_event).and_return(event)

      mapper.run
      item.reload

      expect(item.primary_mapping.mapped_by).to be_nil
      expect(item.primary_mapping.mapped_by_human?).to be false
    end

    context "when the primary mapping was made by a human" do
      it "does not remap the item" do
        original_event = create(:event)
        user = create(:user)
        Ledger::Mapping.map_primary!(ledger: original_event.ledger, ledger_item: item, mapped_by: user)

        new_event = create(:event)
        allow(mapper).to receive(:calculate_card_grant).and_return(nil)
        allow(mapper).to receive(:calculate_event).and_return(new_event)

        expect(mapper.run).to be_nil
        item.reload

        expect(item.primary_ledger).to eq(original_event.ledger)
        expect(item.primary_mapping.mapped_by).to eq(user)
      end
    end

    context "when the primary mapping was made by the system" do
      it "remaps the item when the calculated ledger changes" do
        original_event = create(:event)
        Ledger::Mapping.map_primary!(ledger: original_event.ledger, ledger_item: item, mapped_by: Ledger::Mapper::SYSTEM)

        new_event = create(:event)
        allow(mapper).to receive(:calculate_card_grant).and_return(nil)
        allow(mapper).to receive(:calculate_event).and_return(new_event)

        expect { mapper.run }.not_to(change { Ledger::Mapping.count })
        item.reload

        expect(item.primary_ledger).to eq(new_event.ledger)
      end

      it "keeps the existing mapping when no ledger can be calculated" do
        event = create(:event)
        Ledger::Mapping.map_primary!(ledger: event.ledger, ledger_item: item, mapped_by: Ledger::Mapper::SYSTEM)

        allow(mapper).to receive(:calculate_card_grant).and_return(nil)
        allow(mapper).to receive(:calculate_event).and_return(nil)

        expect { mapper.run }.not_to raise_error
        item.reload

        expect(item.primary_ledger).to eq(event.ledger)
      end
    end

    it "does not touch non-primary mappings when mapping the primary ledger" do
      non_primary_ledger = create(:ledger)
      non_primary = Ledger::Mapping.map_non_primary!(ledger: non_primary_ledger, ledger_item: item, mapped_by: create(:user))

      event = create(:event)
      allow(mapper).to receive(:calculate_card_grant).and_return(nil)
      allow(mapper).to receive(:calculate_event).and_return(event)

      mapper.run
      non_primary.reload

      expect(non_primary.on_primary_ledger).to be false
      expect(non_primary.ledger).to eq(non_primary_ledger)
      expect(item.reload.primary_ledger).to eq(event.ledger)
    end
  end
end
