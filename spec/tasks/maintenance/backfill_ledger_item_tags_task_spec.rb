# frozen_string_literal: true

require "rails_helper"

RSpec.describe Maintenance::BackfillLedgerItemTagsTask do
  let(:event) { create(:event) }
  let(:tag) { event.tags.create!(label: "Snacks", emoji: "🍕", color: "muted") }

  def hcb_code_with_ledger_item
    create(:canonical_transaction).local_hcb_code.tap(&:reload)
  end

  it "copies an HcbCodeTag onto its HCB code's ledger item" do
    hcb_code = hcb_code_with_ledger_item
    hcb_code_tag = HcbCodeTag.create!(hcb_code:, tag:)

    described_class.new.process(hcb_code_tag)

    expect(hcb_code.ledger_item.reload.tags).to include(tag)
  end

  it "preserves the original timestamps" do
    hcb_code = hcb_code_with_ledger_item
    hcb_code_tag = HcbCodeTag.create!(hcb_code:, tag:, created_at: 3.days.ago)

    described_class.new.process(hcb_code_tag)

    ledger_item_tag = Ledger::Item::Tag.find_by(ledger_item_id: hcb_code.ledger_item_id, tag_id: tag.id)
    expect(ledger_item_tag.created_at).to be_within(1.second).of(hcb_code_tag.created_at)
  end

  it "is idempotent when the pair already exists" do
    hcb_code = hcb_code_with_ledger_item
    hcb_code_tag = HcbCodeTag.create!(hcb_code:, tag:)

    described_class.new.process(hcb_code_tag)

    expect { described_class.new.process(hcb_code_tag) }.not_to change(Ledger::Item::Tag, :count)
  end
end
