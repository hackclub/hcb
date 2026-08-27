# frozen_string_literal: true

require "rails_helper"

RSpec.describe InvoiceService::Create, type: :model do
  before do
    expect_any_instance_of(Sponsor).to receive(:create_stripe_customer).and_return(true)
  end

  it "creates a Stripe invoice and invoice item" do
    freeze_time do
      user = create(:user)
      event = create(:event, name: "Scrapyard")
      due_date = (Date.current + 14).to_s
      due_date_unix = Time.find_zone("UTC").parse(due_date).to_i

      service =
        InvoiceService::Create.new(
          event_id: event.id,
          due_date:,
          item_description: "Item description",
          item_amount: "100.00",
          current_user: user,
          sponsor_id: nil,
          sponsor_name: "Sponsor Name",
          sponsor_email: "sponsor@email.com",
          sponsor_address_line1: "123 Main St",
          sponsor_address_line2: nil,
          sponsor_address_city: "Santa Monica",
          sponsor_address_state: "CA",
          sponsor_address_postal_code: "90401",
          sponsor_address_country: "US"
        )

      stripe_invoice = Stripe::Invoice.construct_from(
        id: "in_1234",
        send_invoice: true,
        amount_due: 100_00,
        amount_paid: 0,
        amount_remaining: 100_00,
        attempt_count: 1,
        attempted: true,
        auto_advance: true,
        due_date: due_date_unix,
        ending_balance: 100_00,
        finalized_at: Time.now.to_i,
        hosted_invoice_url: "https://example.com",
        invoice_pdf: "https://example.com/invoice.pdf",
        livemode: false,
        description: "Invoice Memo",
        number: 1234,
        starting_balance: 0,
        statement_descriptor: "Statement Descriptor",
        status: "paid",
        charge: { id: "ch_1234", payment_method_details: { type: nil } },
        subtotal: 100_00,
        tax: 0,
        tax_percent: 0,
        total: 100_00,
      )

      expect(stripe_invoice).to receive(:send_invoice)

      expect(StripeService::Invoice).to(
        receive(:create)
          .with(
            {
              auto_advance: true,
              collection_method: "send_invoice",
              customer: nil,
              description: "To support Scrapyard. Scrapyard is fiscally sponsored by The Hack Foundation (d.b.a. Hack Club), a 501(c)(3) nonprofit with the EIN 81-2908499.",
              due_date: due_date_unix,
              footer: "\n\n\n\n\nNeed to pay by mailed paper check?\n\nPlease pay the amount to the order of The Hack Foundation, and include 'Scrapyard (##{event.id})' in the memo. Checks can be mailed to:\n\nScrapyard (##{event.id}) c/o The Hack Foundation\n8605 Santa Monica Blvd #86294\nWest Hollywood, CA 90069",
              metadata: { event_id: event.id },
              payment_settings: {},
              statement_descriptor: "HCB* Scrapyard",
              status: nil
            }
          )
          .and_return(stripe_invoice)
      )

      expect(StripeService::InvoiceItem).to(
        receive(:create)
          .with(
            {
              amount: 100_00,
              currency: "usd",
              customer: nil,
              description: "Item description",
              invoice: stripe_invoice.id,
            }
          )
          .and_return(Stripe::InvoiceItem.construct_from(id: "ii_1234"))
      )

      expect(StripeService::Invoice).to(
        receive(:retrieve)
          .with(
            {
              id: stripe_invoice.id,
              expand: ["charge", "charge.payment_method_details", "charge.balance_transaction"],
            }
          )
          .and_return(stripe_invoice)
      )

      expect do
        service.run
      end.to change(Invoice, :count).by(1)

      invoice = Invoice.last
      expect(invoice.item_stripe_id).to eq("ii_1234")
      expect(invoice.line_items.count).to eq(1)
      expect(invoice.line_items.first).to have_attributes(description: "Item description", amount: 100_00, item_stripe_id: "ii_1234")
      expect(invoice.stripe_invoice_id).to eq("in_1234")
      expect(invoice.amount_due).to eq(100_00)
      expect(invoice.amount_paid).to eq(0)
      expect(invoice.amount_remaining).to eq(100_00)
      expect(invoice.starting_balance).to eq(0)
      expect(invoice.ending_balance).to eq(100_00)
      expect(invoice.subtotal).to eq(100_00)
      expect(invoice.tax).to eq(0)
      expect(invoice.total).to eq(100_00)
      expect(invoice.attempt_count).to eq(1)
      expect(invoice.attempted).to eq(true)
      expect(invoice.auto_advance).to eq(true)
      expect(invoice.due_date.to_i).to eq(due_date_unix)
      expect(invoice.hosted_invoice_url).to eq("https://example.com")
      expect(invoice.invoice_pdf).to eq("https://example.com/invoice.pdf")
      expect(invoice.livemode).to eq(false)
      expect(invoice.memo).to eq("Invoice Memo")
      expect(invoice.number).to eq("1234")
      expect(invoice.statement_descriptor).to eq("Statement Descriptor")
      expect(invoice.status).to eq("paid")
      expect(invoice.stripe_charge_id).to eq("ch_1234")
      expect(invoice.finalized_at).to be_present
    end
  end

  it "creates a Stripe invoice item per line item" do
    freeze_time do
      user = create(:user)
      event = create(:event, name: "Scrapyard")
      due_date = (Date.current + 14).to_s
      due_date_unix = Time.find_zone("UTC").parse(due_date).to_i

      service =
        InvoiceService::Create.new(
          event_id: event.id,
          due_date:,
          line_items: [
            { description: "Silver sponsorship", amount: "100.00" },
            { description: "Gold sponsorship", amount: "200.00" },
          ],
          current_user: user,
          sponsor_id: nil,
          sponsor_name: "Sponsor Name",
          sponsor_email: "sponsor@email.com",
          sponsor_address_line1: "123 Main St",
          sponsor_address_line2: nil,
          sponsor_address_city: "Santa Monica",
          sponsor_address_state: "CA",
          sponsor_address_postal_code: "90401",
          sponsor_address_country: "US"
        )

      stripe_invoice = Stripe::Invoice.construct_from(
        id: "in_5678",
        send_invoice: true,
        amount_due: 300_00,
        amount_paid: 0,
        amount_remaining: 300_00,
        attempt_count: 1,
        attempted: true,
        auto_advance: true,
        due_date: due_date_unix,
        ending_balance: 300_00,
        finalized_at: Time.now.to_i,
        hosted_invoice_url: "https://example.com",
        invoice_pdf: "https://example.com/invoice.pdf",
        livemode: false,
        description: "Invoice Memo",
        number: 5678,
        starting_balance: 0,
        statement_descriptor: "Statement Descriptor",
        status: "open",
        charge: { id: "ch_5678", payment_method_details: { type: nil } },
        subtotal: 300_00,
        tax: 0,
        tax_percent: 0,
        total: 300_00,
      )

      allow(stripe_invoice).to receive(:send_invoice)
      allow(StripeService::Invoice).to receive(:create).and_return(stripe_invoice)
      allow(StripeService::Invoice).to receive(:retrieve).and_return(stripe_invoice)

      expect(StripeService::InvoiceItem).to(
        receive(:create)
          .with(hash_including(amount: 100_00, description: "Silver sponsorship", invoice: stripe_invoice.id))
          .and_return(Stripe::InvoiceItem.construct_from(id: "ii_5678a"))
      )
      expect(StripeService::InvoiceItem).to(
        receive(:create)
          .with(hash_including(amount: 200_00, description: "Gold sponsorship", invoice: stripe_invoice.id))
          .and_return(Stripe::InvoiceItem.construct_from(id: "ii_5678b"))
      )

      expect do
        service.run
      end.to change(Invoice, :count).by(1).and change(Invoice::LineItem, :count).by(2)

      invoice = Invoice.last
      expect(invoice.item_amount).to eq(300_00)
      expect(invoice.item_description).to eq("Silver sponsorship")
      expect(invoice.item_stripe_id).to eq("ii_5678a")
      expect(invoice.line_items.pluck(:description, :amount, :item_stripe_id)).to eq(
        [
          ["Silver sponsorship", 100_00, "ii_5678a"],
          ["Gold sponsorship", 200_00, "ii_5678b"],
        ]
      )
    end
  end

end
