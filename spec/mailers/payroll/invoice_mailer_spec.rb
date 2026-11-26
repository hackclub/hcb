# frozen_string_literal: true

require "rails_helper"

RSpec.describe Payroll::InvoiceMailer, type: :mailer do
  describe "#rejected" do
    let(:manager) { create(:user, email: "manager@example.invalid") }
    let(:event) { create(:event, organizers: [manager]) }
    let(:payee) { create(:payee, event:, email: "payee@example.invalid") }
    let(:position) { create(:payroll_position, payee:, aasm_state: :onboarded) }
    let(:invoice) { position.invoices.create!(name: "Week 1 hours", amount_cents: 50_00, currency: position.currency, start_date: position.start_date, end_date: position.start_date) }

    before { allow(User).to receive(:system_user).and_return(create(:user, email: User::SYSTEM_USER_EMAIL)) }

    it "goes to the contractor's account holders, not the organization, with replies to the reviewer" do
      payee.legal_entity.users << create(:user, email: "contractor@example.invalid")
      invoice.mark_rejected!(manager, "Missing hours breakdown")

      mail = described_class.with(invoice:).rejected

      expect(mail.to).to eq(["contractor@example.invalid"])
      expect(mail.reply_to).to eq(["manager@example.invalid"])
      expect(mail.body.decoded).to include("Missing hours breakdown")
    end

    it "escapes the reviewer's reason" do
      invoice.mark_rejected!(manager, %(<a href="https://evil.example">Click to re-verify</a>))

      body = described_class.with(invoice:).rejected.body.decoded

      expect(body).not_to include(%(<a href="https://evil.example">))
      expect(body).to include("&lt;a href=")
    end

    it "omits the reason line for invoices rejected without one" do
      invoice.mark_rejected!(manager)

      expect(described_class.with(invoice:).rejected.body.decoded).not_to include("Reason:")
    end
  end
end
