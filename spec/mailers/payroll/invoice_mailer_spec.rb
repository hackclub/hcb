# frozen_string_literal: true

require "rails_helper"

RSpec.describe Payroll::InvoiceMailer, type: :mailer do
  let(:manager) { create(:user, email: "manager@example.invalid") }
  let(:reviewer) { create(:user, email: "reviewer@example.invalid", full_name: "Rita Reviewer") }
  let(:event) { create(:event, name: "Hack the Planet", organizers: [manager]) }
  let(:payee) { create(:payee, event:, email: "payee@example.invalid") }
  let(:position) { create(:payroll_position, payee:, aasm_state: :onboarded) }
  let(:invoice) { position.invoices.create!(name: "Week 1 hours", amount_cents: 50_00, currency: position.currency) }

  before do
    allow(User).to receive(:system_user).and_return(create(:user, email: User::SYSTEM_USER_EMAIL))
  end

  describe "#rejected" do
    let(:reason) { "The hours don't match.\n<b>Please</b> resubmit." }
    let(:mail) { described_class.with(invoice: Payroll::Invoice.find(invoice.id)).rejected }

    before { invoice.reject(reviewed_by: reviewer, reason:) }

    it "tells the contractor why, with replies going to the reviewer" do
      expect(mail.to).to eq(["payee@example.invalid"])
      expect(mail.reply_to).to eq(["reviewer@example.invalid"])
      expect(mail.subject).to eq("Your $50.00 invoice to Hack the Planet was rejected")

      body = mail.body.encoded
      expect(body).to include("Week 1 hours")
      expect(body).to include("Rita Reviewer gave this reason")
      expect(body).to include("The hours don&#39;t match.")
      expect(body).to include("submit a new one on HCB")
    end

    it "escapes the reason and keeps its line breaks" do
      body = mail.body.encoded

      expect(body).to include("&lt;b&gt;Please&lt;/b&gt; resubmit.")
      expect(body).not_to include("<b>Please</b>")
      expect(body).to match(/match\.\s*<br ?\/?>/)
    end

    it "goes to the legal entity's users when the contractor has an account" do
      payee.legal_entity.users << create(:user, email: "contractor@example.invalid")

      expect(mail.to).to eq(["contractor@example.invalid"])
    end

    it "also lets the contractor reach the position's manager" do
      position.update!(manager:)

      expect(mail.reply_to).to eq(["reviewer@example.invalid", "manager@example.invalid"])
    end

    it "doesn't invite a new invoice once the position has ended" do
      position.update_column(:aasm_state, "terminated")

      expect(mail.body.encoded).not_to include("submit a new one")
    end
  end
end
