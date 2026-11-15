# frozen_string_literal: true

require "rails_helper"

RSpec.describe Payroll::InvoiceMailer, type: :mailer do
  describe "#rejected" do
    let(:manager) { create(:user, email: "manager@example.invalid") }
    let(:event) { create(:event, organizers: [manager]) }
    let(:payee) { create(:payee, event:, email: "payee@example.invalid") }
    let(:position) { create(:payroll_position, payee:, aasm_state: :onboarded) }
    let(:invoice) { position.invoices.create!(name: "Engineering hours", amount_cents: 50_00, currency: position.currency) }
    let(:mail) { described_class.with(invoice:).rejected }

    before do
      allow(User).to receive(:system_user).and_return(create(:user, email: User::SYSTEM_USER_EMAIL))
      invoice.mark_rejected!(manager, "Hours are off.\n<script>alert(1)</script>")
    end

    it "goes to the payee alone when they have no HCB account, with replies routed to the reviewer" do
      expect(mail.to).to eq(["payee@example.invalid"])
      expect(mail.cc).to be_blank
      expect(mail.reply_to).to eq(["manager@example.invalid"])
    end

    it "goes to the users of the payee's legal entity once they have one" do
      create(:legal_entity_user, legal_entity: payee.legal_entity, user: create(:user, email: "contractor@example.invalid"))

      expect(mail.to).to eq(["contractor@example.invalid"])
    end

    it "escapes the reason" do
      expect(mail.body.encoded).to include("Hours are off.").and include("&lt;script&gt;")
      expect(mail.body.encoded).not_to include("<script>")
    end
  end
end
