# frozen_string_literal: true

require "rails_helper"

RSpec.describe PayoutService::Invoice::Create do
  before do
    expect_any_instance_of(InvoicePayout).to receive(:create_stripe_payout).and_return(true)
    expect_any_instance_of(Sponsor).to receive(:create_stripe_customer).and_return(true)
  end

  def setup_context
    invoice = create(:invoice)

    service = described_class.new(invoice_id: invoice.id)
    allow(service).to receive(:funds_available?).and_return(true)
    allow(service).to receive(:charge).and_return(true)

    { invoice:, service: }
  end

  it "creates a payout" do
    setup_context => { service: }

    expect do
      service.run
    end.to change(InvoicePayout, :count).by(1)
  end

  it "creates a fee_reimbursement" do
    setup_context => { service: }

    expect do
      service.run
    end.to change(FeeReimbursement, :count).by(1)
  end

  it "updates invoice with relationships" do
    setup_context => { service:, invoice: }

    expect(invoice.payout_id).to be_nil
    expect(invoice.fee_reimbursement_id).to be_nil

    service.run

    invoice.reload

    expect(invoice.payout_id).to be_present
    expect(invoice.fee_reimbursement_id).to be_present
  end
end
