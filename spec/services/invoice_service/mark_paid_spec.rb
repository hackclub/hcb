# frozen_string_literal: true

require "rails_helper"

RSpec.describe InvoiceService::MarkPaid do
  let(:user) { create(:user) }
  let(:invoice) { create(:invoice) }

  before do
    expect_any_instance_of(Sponsor).to receive(:create_stripe_customer).and_return(true)
    allow_any_instance_of(GovernanceService::Admin::Transfer::Approval).to receive(:ensure_may_approve!)
    allow_any_instance_of(Invoice).to receive(:remote_invoice).and_return(stripe_invoice)
  end

  def build_stripe_invoice(status:, payments: [], paid_at: nil)
    Stripe::Invoice.construct_from(
      id: "in_1234", status:, amount_due: 100_00, amount_paid: 0, amount_remaining: 100_00,
      attempt_count: 0, attempted: false, auto_advance: false, due_date: 1.week.from_now.to_i,
      ending_balance: nil, hosted_invoice_url: nil, invoice_pdf: nil, livemode: false, description: nil,
      number: "1234", starting_balance: 0, statement_descriptor: nil, subtotal: 100_00, total: 100_00,
      total_taxes: [], status_transitions: { finalized_at: nil, paid_at: }, payments: { data: payments }
    )
  end

  def run
    described_class.new(invoice_id: invoice.id, reason: "Paid by check", user:).run
  end

  context "when Stripe already collected a charge for the invoice" do
    let(:stripe_invoice) do
      build_stripe_invoice(
        status: "paid",
        payments: [{ status: "paid", payment: { type: "payment_intent", payment_intent: { latest_charge: { id: "ch_1234" } } } }]
      )
    end

    it "refuses so the sponsor isn't counted as paying twice" do
      expect(stripe_invoice).not_to receive(:pay)

      expect { run }.to raise_error(ArgumentError, /already paid through Stripe/)
      expect(invoice.reload).to be_open_v2
    end
  end

  context "when the invoice is still open on Stripe" do
    let(:stripe_invoice) do
      build_stripe_invoice(status: "open", payments: [{ status: "open", payment: { type: "payment_intent", payment_intent: "pi_1234" } }])
    end

    it "records an out of band payment on Stripe instead of charging the sponsor" do
      expect(stripe_invoice).to receive(:pay).with(paid_out_of_band: true).and_return(build_stripe_invoice(status: "paid", paid_at: Time.current.to_i))

      freeze_time do
        run

        expect(invoice.reload).to be_paid_v2
        expect(invoice.status).to eq("paid")
        expect(invoice.manually_marked_as_paid_at).to eq(Time.current)
        expect(invoice.manually_marked_as_paid_user).to eq(user)
        expect(invoice.stripe_charge_id).to be_nil
      end
    end
  end

  context "when the invoice was already paid out of band on Stripe" do
    let(:paid_at) { 3.days.ago.change(usec: 0) }
    let(:stripe_invoice) { build_stripe_invoice(status: "paid", paid_at: paid_at.to_i) }

    it "keeps Stripe's paid_at without paying again" do
      expect(stripe_invoice).not_to receive(:pay)

      run

      expect(invoice.reload).to be_paid_v2
      expect(invoice.manually_marked_as_paid_at).to eq(paid_at)
    end
  end
end
