# frozen_string_literal: true

require "rails_helper"

RSpec.describe Invoice, type: :model do
  before do
    expect_any_instance_of(Sponsor).to receive(:create_stripe_customer).and_return(true)
  end

  it "is valid" do
    invoice = create(:invoice)
    expect(invoice).to be_valid
  end

  describe "ledger item" do
    it "eagerly creates an empty ledger item on create" do
      invoice = create(:invoice)

      item = invoice.ledger_item
      expect(item).to be_present
      expect(item.linked_object).to eq(invoice)
      expect(item.status).to eq("empty")
      expect(item.amount_cents).to eq(0)
      # Mapped to the event's ledger via the linked object, even without a CPT.
      expect(item.primary_ledger).to eq(invoice.event.ledger)
    end

    it "reuses the eager ledger item when the invoice's pending transaction is created" do
      invoice = create(:invoice)
      eager_item = invoice.ledger_item

      raw_pending_invoice_transaction = create(:raw_pending_invoice_transaction, invoice_transaction_id: invoice.id)
      cpt = create(:canonical_pending_transaction, raw_pending_invoice_transaction:)

      # The CPT resolves its ledger item via the linked object (the invoice),
      # so it reuses the eager item rather than creating a duplicate.
      expect(cpt.reload.ledger_item).to eq(eager_item)
      expect(Ledger::Item.where(linked_object: invoice).count).to eq(1)
    end
  end
end
