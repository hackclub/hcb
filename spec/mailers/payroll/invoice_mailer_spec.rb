# frozen_string_literal: true

require "rails_helper"

RSpec.describe Payroll::InvoiceMailer, type: :mailer do
  describe "#reviewed" do
    let(:manager) { create(:user, full_name: "Morgan Manager", email: "manager@example.invalid") }
    let(:event) { create(:event, organizers: [manager]) }
    let(:payee) { create(:payee, event:, email: "payee@example.invalid") }
    let(:position) { create(:payroll_position, payee:, aasm_state: :onboarded) }
    let(:invoice) { position.invoices.create!(name: "Week 1 hours", amount_cents: 50_00, currency: position.currency, start_date: position.start_date, end_date: position.start_date) }

    before { allow(User).to receive(:system_user).and_return(create(:user, email: User::SYSTEM_USER_EMAIL)) }

    it "goes to the contractor's account holders, not the organization, with replies to the reviewer" do
      payee.legal_entity.users << create(:user, email: "contractor@example.invalid")
      invoice.mark_rejected!(manager, "Missing hours breakdown")

      mail = described_class.with(invoice:).reviewed

      expect(mail.to).to eq(["contractor@example.invalid"])
      expect(mail.reply_to).to eq(["manager@example.invalid"])
      expect(mail.subject).to end_with("was rejected")
      expect(mail.body.decoded).to include("Missing hours breakdown")
    end

    it "tells the contractor an approved invoice will be paid" do
      allow_any_instance_of(Event).to receive(:balance_available_v2_cents).and_return(100_00)
      invoice.approve(reviewed_by: manager, review_note: "Good work!")

      mail = described_class.with(invoice:).reviewed

      expect(mail.subject).to end_with("was approved")
      expect(mail.body.decoded).to include("Good work!", "Payment will be sent")
      expect(mail.body.decoded).not_to include("corrected invoice")
    end

    it "escapes the reviewer's note" do
      invoice.mark_rejected!(manager, %(<a href="https://evil.example">Click to re-verify</a>))

      body = described_class.with(invoice:).reviewed.body.decoded

      expect(body).not_to include(%(<a href="https://evil.example">))
      expect(body).to include("&lt;a href=")
    end
  end
end
