# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tag, type: :model do
  let(:event) { create(:event) }

  it "belongs to its ledger's tag list and resolves the event through it" do
    tag = event.tag_list.tags.create!(label: "Snacks", emoji: "🍕", color: "muted")

    expect(tag.tag_list).to eq(event.ledger.tag_list)
    expect(tag.event).to eq(event)
    expect(event.tags).to contain_exactly(tag)
    expect(event.ledger.tags).to contain_exactly(tag)
  end

  it "keeps labels unique within a list, ignoring case" do
    event.tag_list.tags.create!(label: "Snacks", emoji: "🍕", color: "muted")
    duplicate = event.tag_list.tags.build(label: "snacks", emoji: "🎉", color: "red")

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:label]).to include("has already been taken")
  end

  it "allows the same label on another list" do
    event.tag_list.tags.create!(label: "Snacks", emoji: "🍕", color: "muted")
    other = create(:event).tag_list.tags.build(label: "Snacks", emoji: "🎉", color: "red")

    expect(other).to be_valid
  end

  it "shows a card grant's charges the event's tags" do
    allow_any_instance_of(CardGrant).to receive(:transfer_money)
    card_grant = create(:card_grant, event:)
    tag = event.tag_list.tags.create!(label: "Snacks", emoji: "🍕", color: "muted")

    expect(card_grant.ledger.tags).to contain_exactly(tag)
  end
end
