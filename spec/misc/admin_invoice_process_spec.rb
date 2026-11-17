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

  describe "#invoice_process" do
    render_views

    it "renders the amount as money, not raw cents" do
      stub_invoice

      get :invoice_process, params: { id: 7 }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("$555.00")
      expect(response.body).not_to include("55500")
    end

    it "renders as the popover's frame, without the layout" do
      stub_invoice
      request.headers["Turbo-Frame"] = "invoice_process_7"

      get :invoice_process, params: { id: 7 }

      expect(response.body).to include(%(id="invoice_process_7"))
      expect(response.body).not_to include("HCB Admin")
    end

    it "offers no action once the invoice is settled" do
      stub_invoice(status: "paid")

      get :invoice_process, params: { id: 7 }

      expect(response.body).not_to include("Mark as paid")
      expect(response.body).to include("nothing to process")
    end
  end
end
