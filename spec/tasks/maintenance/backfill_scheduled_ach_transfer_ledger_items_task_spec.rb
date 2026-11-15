# frozen_string_literal: true

require "rails_helper"

RSpec.describe Maintenance::BackfillScheduledAchTransferLedgerItemsTask do
  let(:event) { create(:event, :with_positive_balance) }

  # A scheduled transfer created today gets its ledger item eagerly; drop it to
  # stand in for one created before that callback existed.
  def legacy_scheduled_transfer(**attributes)
    transfer = create(:ach_transfer, event:, scheduled_on: 1.week.from_now.to_date, **attributes)
    Ledger::Mapping.where(ledger_item: transfer.ledger_item).delete_all
    transfer.ledger_item.delete
    transfer.reload
  end

  it "collects pending and scheduled transfers that are missing a ledger item" do
    pending = legacy_scheduled_transfer
    scheduled = legacy_scheduled_transfer(aasm_state: :scheduled)
    rejected = legacy_scheduled_transfer(aasm_state: :rejected)
    with_item = create(:ach_transfer, event:, scheduled_on: 1.week.from_now.to_date)
    sent_right_away = create(:ach_transfer, event:)

    expect(with_item.ledger_item).to be_present
    expect(sent_right_away.ledger_item).to be_present
    expect(described_class.collection).to contain_exactly(pending, scheduled)
    expect(described_class.collection).not_to include(rejected, with_item, sent_right_away)
  end

  it "creates an intended ledger item for the transfer" do
    transfer = legacy_scheduled_transfer

    described_class.process(transfer)

    item = transfer.reload.ledger_item
    expect(item).to be_present
    expect(item.status).to eq("intended")
    expect(item.amount_cents).to eq(0)
    expect(item.memo).to eq("ACH to #{transfer.recipient_name}")
    expect(item.hcb_code).to eq(transfer.local_hcb_code)
    expect(item.intended_at).to be_within(1.second).of(transfer.created_at)
    expect(item.primary_ledger).to eq(event.ledger)
  end

  it "leaves a transfer that already has a ledger item alone" do
    transfer = create(:ach_transfer, event:, scheduled_on: 1.week.from_now.to_date)
    item = transfer.ledger_item

    expect { described_class.process(transfer) }.not_to change(Ledger::Item, :count)
    expect(transfer.reload.ledger_item).to eq(item)
  end
end
