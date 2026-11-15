# frozen_string_literal: true

require "rails_helper"

RSpec.describe ReimbursementMailer do
  describe "#review_requested" do
    it "doesn't notify managers who opted out of reviewing" do
      event = create(:event)
      reviewer = create(:user, email: "reviewer@example.com")
      opted_out = create(:user, email: "opted-out@example.com")
      create(:organizer_position, user: reviewer, event:, role: :manager)
      opted_out_position = create(:organizer_position, user: opted_out, event:, role: :manager)
      report = create(:reimbursement_report, event:)

      expect(described_class.with(report:).review_requested.to).to include("opted-out@example.com", "reviewer@example.com")

      opted_out_position.reimbursement_reviewer_opt_ins.destroy_all

      expect(described_class.with(report:).review_requested.to).to eq(["reviewer@example.com"])
    end
  end

  describe "#expenses_approved" do
    it "renders the list of expenses in their original currency" do
      user = create(
        :user,
        full_name: "Test User",
        email: "user@example.com",
      )
      user.personal_legal_entity.payout_methods.create!(
        default: true,
        details: LegalEntity::PayoutMethod::WiseTransfer.new(
          address_line1: "123 Rue Main",
          address_city: "Shawinigan",
          address_state: "QC",
          recipient_country: "CA",
          address_postal_code: "G0X1L0",
          currency: "CAD",
        )
      )
      event = create(:event, name: "Daydream")

      report = Reimbursement::Report.create!(
        name: "Food & drinks for event",
        user:,
        event:,
        currency: "CAD",
      )

      drinks = report.expenses.create!(value: 12.34, memo: "Drinks", category: "Food & Entertainment")
      ReceiptService::Create.new(
        receiptable: drinks,
        uploader: user,
        attachments: [file_fixture("receipt.png")],
        upload_method: :receipts_page
      ).run!

      food = report.expenses.create!(value: 34.56, memo: "Food", category: "Food & Entertainment")
      ReceiptService::Create.new(
        receiptable: food,
        uploader: user,
        attachments: [file_fixture("receipt.png")],
        upload_method: :receipts_page
      ).run!

      report.mark_submitted!

      mail = described_class.with(report:, expenses: report.expenses).expenses_approved

      expect { mail.deliver_now }.to send_email(
        from: "hcb@staging.hcb.hackclub.com",
        to: "user@example.com",
        subject: "[Reimbursements] Expenses approved for Food & drinks for event"
      )

      body = Nokogiri::HTML5.parse(mail.html_part.body.to_s)

      expect(body.css("ul li").map { |el| el.text.squish }).to eq(
        ["Drinks for $12.34 CAD", "Food for $34.56 CAD"]
      )
    end
  end

  describe "#wise_transfer_failed" do
    it "tells the reimbursee why their Wise payout failed and where to fix their details" do
      create(:event, id: EventMappingEngine::EventIds::REIMBURSEMENT_CLEARING)
      user = create(:user, email: "user@example.com")
      report = create(:reimbursement_report, user:, name: "Food & drinks for event")
      payout_holding = Reimbursement::PayoutHolding.create!(report:, amount_cents: 130_00, aasm_state: :failed)

      mail = described_class.with(reimbursement_payout_holding: payout_holding, reason: "Account number is invalid").wise_transfer_failed

      expect { mail.deliver_now }.to send_email(
        to: "user@example.com",
        subject: "[Reimbursements] Wise transfer for Food & drinks for event failed to send"
      )

      body = Nokogiri::HTML5.parse(mail.html_part.body.to_s)
      expect(body.css("pre").map(&:text)).to eq(["Account number is invalid"])
      expect(body.css("a").map { |a| a["href"] }).to include(Rails.application.routes.url_helpers.settings_payouts_url)
    end
  end
end
