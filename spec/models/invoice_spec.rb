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
    it "eagerly creates an intended ledger item on create" do
      invoice = create(:invoice)

      item = invoice.ledger_item
      expect(item).to be_present
      expect(item.linked_object).to eq(invoice)
      expect(item.status).to eq("intended")
      expect(item.amount_cents).to eq(0)
      # intended_at captures the creation time and is preserved through refresh!.
      expect(item.intended_at).to be_within(1.second).of(invoice.created_at)
      expect(item.datetime).to be_within(1.second).of(invoice.created_at)
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

RSpec.describe Invoice, "#set_fields_from_stripe_invoice", type: :model do
  before do
    expect_any_instance_of(Sponsor).to receive(:create_stripe_customer).and_return(true)
  end

  let(:invoice) { create(:invoice, stripe_charge_id: "ch_existing") }

  def build_stripe_invoice(**overrides)
    Stripe::Invoice.construct_from(
      {
        id: "in_1234", status: "open", amount_due: 100_00, amount_paid: 0, amount_remaining: 100_00,
        attempt_count: 0, attempted: false, auto_advance: false, due_date: 1.week.from_now.to_i,
        ending_balance: nil, hosted_invoice_url: nil, invoice_pdf: nil, livemode: false, description: nil,
        number: "1234", starting_balance: 0, statement_descriptor: nil, subtotal: 100_00, total: 100_00,
        total_taxes: [{ amount: 7_00, type: "tax_rate_details" }], status_transitions: { finalized_at: nil, paid_at: nil }
      }.merge(overrides)
    )
  end

  it "reads the charge and card behind the payment that paid the invoice" do
    checks = { address_line1_check: "pass", address_postal_code_check: "pass", cvc_check: "pass" }
    card = { brand: "visa", country: "US", exp_month: 1, exp_year: 2030, funding: "credit", last4: "4242", checks: }
    payment_intent = { latest_charge: { id: "ch_1234", payment_method_details: { type: "card", card: } } }

    invoice.set_fields_from_stripe_invoice(
      build_stripe_invoice(
        status: "paid",
        payments: {
          data: [
            { status: "canceled", payment: { type: "payment_intent", payment_intent: { latest_charge: { id: "ch_canceled" } } } },
            { status: "paid", payment: { type: "payment_intent", payment_intent: } }
          ]
        }
      )
    )

    expect(invoice.stripe_charge_id).to eq("ch_1234")
    expect(invoice.payment_method_type).to eq("card")
    expect(invoice.payment_method_card_last4).to eq("4242")
    expect(invoice.tax).to eq(7_00)
  end

  it "has no charge while the only payment is still open" do
    invoice.set_fields_from_stripe_invoice(
      build_stripe_invoice(payments: { data: [{ status: "open", payment: { type: "payment_intent", payment_intent: "pi_1234" } }] })
    )

    expect(invoice.stripe_charge_id).to be_nil
    expect(invoice.payment_method_type).to be_nil
  end

  it "keeps the charge when the response doesn't expand payments" do
    invoice.set_fields_from_stripe_invoice(build_stripe_invoice(status: "void"))

    expect(invoice.status).to eq("void")
    expect(invoice.stripe_charge_id).to eq("ch_existing")
  end
end
