# frozen_string_literal: true

require "rails_helper"

RSpec.describe ReimbursementMailer do
  describe "#review_requested" do
    let(:manager) { create(:user) }
    let(:bot) { create(:user) }
    let(:parent_manager) { create(:user) }
    let(:parent) { create(:event, organizers: [parent_manager]) }
    let(:event) { create(:event, parent:, organizers: [manager, bot]) }
    let(:report) { create(:reimbursement_report, event:, reviewer: bot, aasm_state: :submitted) }

    it "notifies just the selected reviewer when reviewer selection is enabled" do
      mail = described_class.with(report:).review_requested

      expect(mail.to).to contain_exactly(bot.email)
    end

    it "notifies all eligible managers when selection is disabled, even with an existing bot assignment" do
      event.update!(reimbursements_allow_reviewer_selection: false)
      event.config.update!(contact_email: "reimbursements@example.com")

      mail = described_class.with(report:).review_requested

      expect(mail.to).to contain_exactly(manager.email, bot.email, parent_manager.email, "reimbursements@example.com")
      expect(mail.subject).to include("Review Requested:")
    end

    it "notifies managers of parent organizations for unassigned reports" do
      report.update!(reviewer: nil)

      mail = described_class.with(report:).review_requested

      expect(mail.to).to contain_exactly(manager.email, bot.email, parent_manager.email)
    end

    it "excludes the reimbursee and non-managers from the manager notification" do
      event.update!(reimbursements_allow_reviewer_selection: false)
      create(:organizer_position, event:, user: report.user)
      create(:organizer_position, event:, role: :member)

      mail = described_class.with(report:).review_requested

      expect(mail.to).to contain_exactly(manager.email, bot.email, parent_manager.email)
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
end
