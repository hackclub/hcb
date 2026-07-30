# frozen_string_literal: true

require "rails_helper"

RSpec.describe Maintenance::BackfillLedgerItemSpecialAppearancesTask do
  let(:appearance) { Ledger::Item::SpecialAppearance.find(:hackathon_grant) }

  it "sets the appearance on an item whose memo is the appearance's memo" do
    item = create(:ledger_item)
    item.update_column(:memo, appearance.memo)

    described_class.new.process(item)

    expect(item.reload.special_appearance).to be(appearance)
  end

  it "collects only un-backfilled items with a matching memo and no custom memo" do
    matching = create(:ledger_item)
    matching.update_column(:memo, appearance.memo)

    unrelated = create(:ledger_item)
    unrelated.update_column(:memo, "Transfer from Hack Club HQ")

    renamed = create(:ledger_item)
    renamed.update_columns(memo: appearance.memo, custom_memo: appearance.memo)

    already_done = create(:ledger_item)
    already_done.update_columns(memo: appearance.memo, special_appearance: "hackathon_grant")

    collection = described_class.new.collection

    expect(collection).to include(matching)
    expect(collection).not_to include(unrelated, renamed, already_done)
  end

  it "leaves updated_at untouched, since the change is cosmetic" do
    item = create(:ledger_item)
    item.update_column(:memo, appearance.memo)
    updated_at = item.reload.updated_at

    described_class.new.process(item)

    expect(item.reload.updated_at).to eq(updated_at)
  end

  # The point of the column: once it's set, refresh! regenerates the same memo
  # from the appearance, so a backfilled item can't drift back.
  it "produces an item whose memo survives a refresh" do
    item = create(:ledger_item)
    item.update_column(:memo, appearance.memo)

    described_class.new.process(item)
    item.reload.refresh!

    expect(item.reload.memo).to eq(appearance.memo)
  end
end
