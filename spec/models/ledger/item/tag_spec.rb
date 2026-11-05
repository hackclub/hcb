# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ledger::Item::Tag, type: :model do
  let(:event) { create(:event) }
  let(:ledger_item) { create(:ledger_item) }
  let(:tag) { event.tags.create!(label: "Snacks", emoji: "🍕", color: "muted") }

  it "associates a ledger item with a top-level Tag" do
    join = described_class.create!(ledger_item:, tag:)

    expect(join.ledger_item).to eq(ledger_item)
    expect(join.tag).to eq(tag)
    # `belongs_to :tag` must resolve to ::Tag, not Ledger::Item::Tag itself.
    expect(join.tag).to be_a(::Tag)
  end

  it "exposes the tag's event" do
    join = described_class.create!(ledger_item:, tag:)

    expect(join.event).to eq(event)
  end

  it "is readable through the ledger item's tags association" do
    described_class.create!(ledger_item:, tag:)

    expect(ledger_item.reload.tags).to include(tag)
  end

  it "rejects a duplicate (ledger_item, tag) pair" do
    described_class.create!(ledger_item:, tag:)

    expect { described_class.create!(ledger_item:, tag:) }.to raise_error(ActiveRecord::RecordNotUnique)
  end
end
