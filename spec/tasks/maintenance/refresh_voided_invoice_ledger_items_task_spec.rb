# frozen_string_literal: true

require "rails_helper"

RSpec.describe Maintenance::RefreshVoidedInvoiceLedgerItemsTask do
  before do
    allow_any_instance_of(Sponsor).to receive(:create_stripe_customer).and_return(true)
  end

  # Voids the invoice without running the event's callbacks, standing in for
  # one voided before Invoice#refresh_ledger_item existed.
  def legacy_voided_invoice
    invoice = create(:invoice)
    invoice.update_column(:aasm_state, "void_v2")
    invoice
  end

  it "collects intended items for voided invoices" do
    voided = legacy_voided_invoice
    open = create(:invoice)

    expect(voided.ledger_item.reload.status).to eq("intended")
    expect(described_class.collection).to contain_exactly(voided.ledger_item)
    expect(described_class.collection).not_to include(open.ledger_item)
  end

  it "marks the item canceled" do
    item = legacy_voided_invoice.ledger_item

    described_class.process(item)

    expect(item.reload.status).to eq("canceled")
  end
end
