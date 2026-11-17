# frozen_string_literal: true

require "rails_helper"

RSpec.describe AdminController, type: :controller do
  include SessionSupport

  before { create_session(create(:user, :make_admin), verified: true) }

  # Creating an Invoice for real talks to Stripe, so stub the lookup.
  def stub_invoice(status: "open", **attrs)
    event = create(:event)
    invoice = build_stubbed(:invoice, id: 7, item_amount: 55_500, status:,
                                      sponsor: build_stubbed(:sponsor, event:), **attrs)
    allow(invoice).to receive_messages(hosted_invoice_url: "https://invoice.stripe.com/x",
                                       invoice_pdf: "https://invoice.stripe.com/x.pdf",
                                       stripe_dashboard_url: "https://dashboard.stripe.com/x",
                                       event:)
    allow(Invoice).to receive(:find).and_return(invoice)
    invoice
  end

  describe "#invoice_mark_paid" do
    it "passes the reason through and returns to the invoices table" do
      stub_invoice
      expect(InvoiceService::MarkPaid).to receive(:new)
        .with(hash_including(invoice_id: 7, reason: "check #1234"))
        .and_return(double(run: true))

      post :invoice_mark_paid, params: { id: 7, reason: "check #1234" }

      expect(response).to redirect_to(invoices_admin_index_path)
    end

    # Previously `Invoice.open.find` raised RecordNotFound here.
    it "explains itself instead of 404ing when the invoice isn't open" do
      invoice = stub_invoice(status: "paid")

      post :invoice_mark_paid, params: { id: 7, reason: "check" }

      expect(response).to redirect_to(invoice_process_admin_path(invoice))
      expect(flash[:error]).to include("already")
    end

    it "surfaces a service failure instead of 500ing" do
      invoice = stub_invoice
      allow(InvoiceService::MarkPaid).to receive(:new).and_raise(StandardError, "Stripe said no")

      post :invoice_mark_paid, params: { id: 7, reason: "check" }

      expect(response).to redirect_to(invoice_process_admin_path(invoice))
      expect(flash[:error]).to eq("Stripe said no")
    end
  end
end
