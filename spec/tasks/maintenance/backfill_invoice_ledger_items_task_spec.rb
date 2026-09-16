# frozen_string_literal: true

require "rails_helper"

RSpec.describe Maintenance::BackfillInvoiceLedgerItemsTask do
  before do
    allow_any_instance_of(Sponsor).to receive(:create_stripe_customer).and_return(true)
  end

  # Simulate an invoice that predates the eager-creation feature: remove its
  # ledger item (and the ledger mapping the mapper created for it, which the
  # ledger_items FK would otherwise block).
  def remove_ledger_item(invoice)
    item = invoice.ledger_item
    item.ledger_mappings.destroy_all
    item.destroy!
    invoice.reload
  end

  it "creates an empty ledger item for an invoice that has none" do
    invoice = create(:invoice)
    remove_ledger_item(invoice)
    expect(invoice.ledger_item).to be_nil

    described_class.new.process(invoice)

    item = invoice.reload.ledger_item
    expect(item).to be_present
    expect(item.linked_object).to eq(invoice)
    expect(item.status).to eq("empty")
    expect(item.amount_cents).to eq(0)
  end

  it "does not create a second ledger item when one already exists" do
    invoice = create(:invoice)
    expect(invoice.ledger_item).to be_present

    expect { described_class.new.process(invoice) }.not_to change(Ledger::Item, :count)
  end

  it "only collects invoices without a ledger item" do
    with_item = create(:invoice)
    without_item = create(:invoice)
    remove_ledger_item(without_item)

    collection = described_class.new.collection

    expect(collection).to include(without_item)
    expect(collection).not_to include(with_item)
  end
end
