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
  end
end
