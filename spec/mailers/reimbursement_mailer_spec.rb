# frozen_string_literal: true

require "rails_helper"

RSpec.describe ReimbursementMailer do
  describe "#expenses_approved" do
    it "renders the list of expenses in their original currency" do
      user = create(
        :user,
        full_name: "Test User",
        email: "user@example.com",
        payout_method: User::PayoutMethod::WiseTransfer.new(
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

      drinks = report.expenses.create!(value: 12.34, memo: "Drinks")
      ReceiptService::Create.new(
        receiptable: drinks,
        uploader: user,
        attachments: [file_fixture("receipt.png")],
        upload_method: :receipts_page
      ).run!

      food = report.expenses.create!(value: 34.56, memo: "Food")
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
end
