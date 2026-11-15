# frozen_string_literal: true

require "rails_helper"

RSpec.describe Maintenance::RefreshVoidedInvoiceLedgerItemsTask do
  before do
    allow_any_instance_of(Sponsor).to receive(:create_stripe_customer).and_return(true)
  end

  # Voids the invoice without refreshing its ledger item, which keeps the
  # status it had before.
  def voided_invoice(**attributes)
    invoice = create(:invoice, **attributes)
    invoice.update_columns(aasm_state: "void_v2")
    invoice
  end

  it "collects the ledger items of voided invoices" do
    voided = voided_invoice
    manually_paid = voided_invoice(manually_marked_as_paid_at: Time.current)
    open = create(:invoice)

    expect(open.ledger_item).to be_present
    expect(described_class.collection).to contain_exactly(voided.ledger_item, manually_paid.ledger_item)
  end

  it "marks a voided invoice's item canceled" do
    item = voided_invoice.ledger_item
    expect(item.reload.status).to eq("intended")

    described_class.process(item)

    expect(item.reload.status).to eq("canceled")
  end

  it "keeps a manually paid invoice's item intended" do
    invoice = voided_invoice(manually_marked_as_paid_at: Time.current)
    item = invoice.ledger_item
    item.update_columns(status: "canceled")

    described_class.process(item)

    expect(item.reload.status).to eq("intended")
  end

  it "places a voided invoice's unmapped item on the invoice's event ledger" do
    invoice = voided_invoice
    item = invoice.ledger_item
    item.update_columns(status: "canceled")
    Ledger::Mapping.where(ledger_item: item).delete_all

    described_class.process(item)

    expect(item.reload.primary_ledger).to eq(invoice.event.ledger)
  end
end
