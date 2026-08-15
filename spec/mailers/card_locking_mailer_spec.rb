# frozen_string_literal: true

require "rails_helper"

RSpec.describe CardLockingMailer, type: :mailer do
  include_context "card locking charges"

  before { travel_to(Time.zone.parse("2026-10-10 12:00:00")) }

  describe "#cards_locked" do
    it "names the overdue count and avoids countdown/violation language" do
      hcb_code = create_settled_card_charge(user:, settled_at: 10.days.ago)
      hcb_code.update!(card_charge_settled_at: 10.days.ago, receipt_due_at: 1.day.ago)

      mail = described_class.cards_locked(user:)

      expect(mail.subject).to match(/locked/i)
      expect(mail.body.encoded).not_to include("72 hours")
      expect(mail.body.encoded).not_to include("violation")
      expect(mail.body.encoded).to include("recurring")
    end
  end

  describe "#cards_unlocked" do
    it "does not promise a lasting unlock when it came from a suppression" do
      hcb_code = create_settled_card_charge(user:, settled_at: 10.days.ago)
      hcb_code.update!(card_charge_settled_at: 10.days.ago, receipt_due_at: 1.day.ago)
      suppressed_until = Time.zone.parse("2026-10-12 15:00:00")

      mail = described_class.cards_unlocked(user:, suppressed_until:)

      expect(mail.subject).to eq("Your HCB cards work again until Oct 12")
      expect(mail.body.encoded).to include("The HCB team has made a one time exception")
      expect(mail.body.encoded).to match(/lock again/i)
    end

    # No sessions on this cardholder, so the deadline renders in the default zone
    # rather than UTC. Getting this wrong shows someone a time hours off the one
    # their cards actually lock at.
    it "renders the deadline in the cardholder's assumed timezone" do
      hcb_code = create_settled_card_charge(user:, settled_at: 10.days.ago)
      hcb_code.update!(card_charge_settled_at: 10.days.ago, receipt_due_at: 1.day.ago)

      mail = described_class.cards_unlocked(user:, suppressed_until: Time.zone.parse("2026-10-12 15:00:00"))

      expect(mail.body.encoded).to include("Oct 12 at 11:00 AM EDT")
    end

    it "lists the oldest outstanding charge first" do
      older = create_settled_card_charge(user:, settled_at: 12.days.ago, amount_cents: -11_00)
      older.update!(card_charge_settled_at: 12.days.ago, receipt_due_at: 3.days.ago)
      newer = create_settled_card_charge(user:, settled_at: 10.days.ago, amount_cents: -22_00)
      newer.update!(card_charge_settled_at: 10.days.ago, receipt_due_at: 1.day.ago)

      body = described_class.cards_unlocked(user:, suppressed_until: 1.day.from_now).body.encoded

      expect(body.index("$11.00")).to be < body.index("$22.00")
    end

    # Without signed links the cardholder has to sign in, which is the friction
    # the exception exists to remove.
    it "links each overdue charge to a signed upload URL" do
      hcb_code = create_settled_card_charge(user:, settled_at: 10.days.ago)
      hcb_code.update!(card_charge_settled_at: 10.days.ago, receipt_due_at: 1.day.ago)

      mail = described_class.cards_unlocked(user:, suppressed_until: 1.day.from_now)

      expect(mail.body.encoded).to include(hcb_code.hashid)
      expect(mail.body.encoded).to match(/[?&]s=/)
    end

    it "keeps the plain copy when the cardholder cleared their receipts" do
      mail = described_class.cards_unlocked(user:)

      expect(mail.subject).to eq("Your HCB cards work again")
      expect(mail.body.encoded).not_to include("one time exception")
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
