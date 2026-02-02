# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ledger::Mapper do
  let(:item) do
    i = Ledger::Item.new(amount_cents: 1000, memo: "Test", date: Time.current)
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
      existing_ledger = Ledger.create!(primary: true, event:)

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
  end
end
