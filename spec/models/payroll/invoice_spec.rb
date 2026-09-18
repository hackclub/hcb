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

    # Two approvals racing (a double-clicked button, or a stale page) must not
    # pay the contractor twice.
    it "pays an invoice only once, even when approved again from a stale copy" do
      stub_balance(100_00)
      invoice = build_invoice.tap(&:save!)
      stale = described_class.find(invoice.id)

      expect(invoice.approve(reviewed_by: approver)).to eq(true)

      expect { expect(stale.approve(reviewed_by: approver)).to eq(false) }
        .not_to change(Payment, :count)
      expect(invoice.reload.payment).to be_present
    end

    it "refuses to pay a rejected invoice" do
      stub_balance(100_00)
      invoice = build_invoice.tap(&:save!)
      invoice.mark_rejected!(approver)

      expect(invoice.approve(reviewed_by: approver)).to eq(false)
      expect(invoice.reload).to be_rejected
      expect(invoice.payment).to be_nil
    end
  end

  describe "amount" do
    # The form only enforces a positive amount client-side, so a crafted
    # request could otherwise mint a zero or negative payment on approval.
    it "rejects amounts that aren't positive" do
      expect(build_invoice(amount_cents: 0)).not_to be_valid
      expect(build_invoice(amount_cents: -1_000)).not_to be_valid
    end

    it "rejects an amount too large for the column" do
      expect(build_invoice(amount_cents: 2**31)).not_to be_valid
    end
  end
end
