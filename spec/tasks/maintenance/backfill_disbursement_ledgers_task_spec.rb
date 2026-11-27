# frozen_string_literal: true

require "rails_helper"

RSpec.describe Maintenance::BackfillDisbursementLedgersTask do
  let(:event) { create(:event) }
  let(:card_grant) do
    ct = create(:canonical_transaction, amount_cents: 100_000, memo: "Test balance")
    create(:canonical_event_mapping, canonical_transaction: ct, event:)
    create(:card_grant, event:)
  end

  # Clears the ledgers, standing in for a disbursement made before they were written.
  def legacy(disbursement)
    disbursement.update_columns(source_ledger_id: nil, destination_ledger_id: nil)
    disbursement
  end

  def backfill
    described_class.new.collection.find_each { |disbursement| described_class.new.process(disbursement) }
  end

  it "collects disbursements missing either ledger" do
    missing_both = legacy(create(:disbursement))
    missing_source = create(:disbursement).tap { |d| d.update_columns(source_ledger_id: nil) }
    filled = create(:disbursement)

    ids = described_class.new.collection.ids

    expect(ids).to include(missing_both.id, missing_source.id)
    expect(ids).not_to include(filled.id)
  end

  it "fills both organizations' ledgers on a transfer between them" do
    transfer = legacy(create(:disbursement))

    backfill
    transfer.reload

    expect(transfer.source_ledger).to eq(transfer.source_event.ledger)
    expect(transfer.destination_ledger).to eq(transfer.destination_event.ledger)
  end

  it "fills the card grant's ledger as the destination of a top-up" do
    topup = legacy(create(:disbursement, source_event: event, event:, destination_subledger: card_grant.subledger))

    backfill
    topup.reload

    expect(topup.source_ledger).to eq(event.ledger)
    expect(topup.destination_ledger).to eq(card_grant.ledger)
  end

  it "fills the card grant's ledger as the source of a withdrawal" do
    withdrawal = legacy(create(:disbursement, source_event: event, event:, source_subledger: card_grant.subledger))

    backfill
    withdrawal.reload

    expect(withdrawal.source_ledger).to eq(card_grant.ledger)
    expect(withdrawal.destination_ledger).to eq(event.ledger)
  end

  it "leaves the side nil for a subledger without a card grant" do
    transfer = legacy(create(:disbursement, source_event: event, event:, destination_subledger: event.subledgers.create!))

    backfill
    transfer.reload

    expect(transfer.source_ledger).to eq(event.ledger)
    expect(transfer.destination_ledger).to be_nil
  end

  it "doesn't overwrite a ledger that's already set" do
    transfer = create(:disbursement)
    other_ledger = create(:event).ledger
    transfer.update_columns(source_ledger_id: other_ledger.id, destination_ledger_id: nil)

    backfill

    expect(transfer.reload.source_ledger).to eq(other_ledger)
  end
end
