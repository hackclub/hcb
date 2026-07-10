# frozen_string_literal: true

require "rails_helper"

RSpec.describe CardLockingMailer, type: :mailer do
  include_context "card locking charges"

  before { travel_to(Time.zone.parse("2026-10-10 12:00:00")) }

  describe "#cards_locked" do
    it "names the overdue count and avoids countdown/violation language" do
      hcb_code = create_settled_card_charge(user:, settled_at: 10.days.ago)
      hcb_code.update!(receipt_settled_at: 10.days.ago, receipt_due_at: 1.day.ago)

      mail = described_class.cards_locked(user:)

      expect(mail.subject).to match(/locked/i)
      expect(mail.body.encoded).not_to include("72 hours")
      expect(mail.body.encoded).not_to include("violation")
      expect(mail.body.encoded).to include("recurring")
    end
  end

  describe "#warning" do
    it "reports a calm pile count and avoids violation/urgent language" do
      create_settled_card_charge(user:, settled_at: 2.days.ago)

      mail = described_class.warning(user:)

      expect(mail.subject).to eq("You have 1 receipt to upload")
      expect(mail.subject).not_to match(/urgent/i)
      expect(mail.body.encoded).not_to include("violation")
      expect(mail.body.encoded).not_to include("72 hours")
    end

    it "pluralizes the subject for more than one receipt" do
      create_settled_card_charge(user:, settled_at: 2.days.ago)
      create_settled_card_charge(user:, settled_at: 1.day.ago)

      mail = described_class.warning(user:)

      expect(mail.subject).to eq("You have 2 receipts to upload")
    end
  end
end
