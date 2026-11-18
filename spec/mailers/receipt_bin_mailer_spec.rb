# frozen_string_literal: true

require "rails_helper"

RSpec.describe ReceiptBinMailer, type: :mailer do
  describe "#bounce_success" do
    let(:user) { create(:user, email: "test@example.com") }

    # A settled transaction's ledger item takes its datetime from the
    # canonical transaction, so the item is "from N days ago" in the email.
    def create_paired_ledger_item(memo:, settled_at:)
      canonical_transaction = create(:canonical_transaction, memo:, date: settled_at.to_date, created_at: settled_at, hcb_code: "HCB-600-iauth_#{SecureRandom.hex(8)}")
      ledger_item = canonical_transaction.local_hcb_code.reload.ledger_item
      Receipt.create!(receiptable: ledger_item, user:, upload_method: :email_receipt_bin,
                      file: { io: file_fixture("receipt.png").open, filename: "receipt.png" })
      ledger_item
    end

    it "lists the transactions each receipt was paired with and links to the HCB code" do
      ledger_item = create_paired_ledger_item(memo: "COFFEE SHOP", settled_at: 3.days.ago)

      mail = described_class.with(to: user.email, receipts_count: 1, paired_with: [ledger_item]).bounce_success
      body = (mail.html_part || mail).body.decoded

      expect(body).to include("We also automatically matched it to the following transaction:")
      expect(body).to include("COFFEE SHOP")
      expect(body).to include("3 days ago")
      expect(body).to include("/hcb/#{ledger_item.hcb_code.hashid}\"")
      expect(body).to include("/hcb/#{ledger_item.hcb_code.hashid}?reverse=#{ledger_item.receipts.last.id}")
    end

    it "does not mention pairing when nothing was paired" do
      mail = described_class.with(to: user.email, receipts_count: 2, paired_with: []).bounce_success
      body = (mail.html_part || mail).body.decoded

      expect(body).to include("We got your receipts, thanks!")
      expect(body).to include("You can find them in your")
      expect(body).not_to include("automatically matched")
    end
  end
end
