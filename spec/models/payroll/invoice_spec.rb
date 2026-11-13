# frozen_string_literal: true

require "rails_helper"

RSpec.describe Payroll::Invoice, type: :model do
  let(:event) { create(:event) }
  let(:payee) { create(:payee, event:) }
  let(:position) { create(:payroll_position, payee:, aasm_state: :onboarded) }
  let(:approver) { create(:user) }

  before do
    allow(User).to receive(:system_user).and_return(create(:user, email: User::SYSTEM_USER_EMAIL))
  end

  def build_invoice(**attrs)
    position.invoices.build(name: "Engineering hours", amount_cents: 1_000, currency: position.currency, **attrs)
  end

  def stub_balance(cents)
    allow_any_instance_of(Event).to receive(:balance_available_v2_cents).and_return(cents)
  end

  describe "validations" do
    it "rejects non-positive amounts" do
      expect(build_invoice(amount_cents: 0)).not_to be_valid
      expect(build_invoice(amount_cents: -100)).not_to be_valid
    end
  end

  describe "manager notification" do
    it "emails the manager when an invoice is left for review" do
      expect { build_invoice.save! }.to have_enqueued_mail(Payroll::InvoiceMailer, :submitted)
    end

    it "stays silent when the invoice was already approved before it committed" do
      stub_balance(100_00)
      invoice = build_invoice

      expect {
        ActiveRecord::Base.transaction do
          invoice.save!
          invoice.approve(reviewed_by: approver)
        end
      }.to have_enqueued_mail(Payroll::InvoiceMailer, :submitted).exactly(0).times
    end
  end

  describe "#approve" do
    it "refuses to pay an invoice the event can't cover, leaving it reviewable" do
      stub_balance(999)
      invoice = build_invoice.tap(&:save!)

      expect(invoice.approve(reviewed_by: approver)).to eq(false)
      expect(invoice.reload).to be_submitted
      expect(invoice.payment).to be_nil
    end

    it "pays only once when two requests approve the same invoice" do
      stub_balance(100_00)
      invoice = build_invoice.tap(&:save!)
      stale_copy = Payroll::Invoice.find(invoice.id)

      expect(invoice.approve(reviewed_by: approver)).to eq(true)
      expect { expect(stale_copy.approve(reviewed_by: approver)).to eq(false) }.not_to change(Payment, :count)
    end
  end

  describe "#status_text" do
    def approved_invoice(payment_state)
      build_invoice(aasm_state: :approved, payment: create(:payment, payee:, aasm_state: payment_state))
    end

    # An invoice HCB refused to pay must never keep reading as a clean approval.
    it "surfaces a payment HCB rejected or that was canceled", :aggregate_failures do
      expect(approved_invoice(:rejected)).to have_attributes(status_text: "Payment rejected", state_color: "error")
      expect(approved_invoice(:canceled)).to have_attributes(status_text: "Payment canceled", state_color: "muted")
    end

    it "only reads as paid once the payment succeeds", :aggregate_failures do
      %i[pending_legal_entity under_review sent].each do |state|
        expect(approved_invoice(state)).to have_attributes(status_text: "Approved", state_color: "success")
      end
      expect(approved_invoice(:successful)).to have_attributes(status_text: "Paid", state_color: "success")
    end

    it "falls back to the review state without a payment", :aggregate_failures do
      expect(build_invoice).to have_attributes(status_text: "Submitted", state_color: "warning")
      expect(build_invoice(aasm_state: :rejected)).to have_attributes(status_text: "Rejected", state_color: "error")
      expect(build_invoice(aasm_state: :approved)).to have_attributes(status_text: "Approved", state_color: "success")
    end
  end
end
