# frozen_string_literal: true

require "rails_helper"

RSpec.describe CanonicalPendingTransactionMailer, type: :mailer do
  def html_body(mail)
    (mail.html_part || mail).body.decoded
  end

  describe "#notify_settled" do
    let(:user) { create(:user, full_name: "Test User", email: "user@example.com") }
    let(:raw_pending_stripe_transaction) { create(:raw_pending_stripe_transaction) }
    let(:stripe_card) { create(:stripe_card, :with_stripe_id, stripe_id: raw_pending_stripe_transaction.stripe_transaction["card"]["id"], user: user) }
    let(:canonical_pending_transaction) { create(:canonical_pending_transaction, raw_pending_stripe_transaction: raw_pending_stripe_transaction, amount_cents: -2000, memo: "Coffee Shop") }
    let(:canonical_transaction) { create(:canonical_transaction, amount_cents: -2500, memo: "Coffee Shop") }

    before do
      stripe_card
    end

    context "when a receipt is missing" do
      it "renders the prompt to upload a receipt" do
        mail = described_class.with(
          canonical_pending_transaction_id: canonical_pending_transaction.id,
          canonical_transaction_id: canonical_transaction.id
        ).notify_settled

        expect(html_body(mail)).to include("Click to upload your receipt")
        expect(html_body(mail)).to include("reply to this email with an image or PDF receipt attached")
        expect(html_body(mail)).not_to include("A receipt has already been uploaded for this transaction")
      end
    end

    context "when a receipt has already been uploaded" do
      it "does not prompt to upload the receipt and clarifies it has already been uploaded" do
        hcb_code = canonical_pending_transaction.local_hcb_code
        ReceiptService::Create.new(
          receiptable: hcb_code,
          uploader: user,
          attachments: [file_fixture("receipt.png")],
          upload_method: :receipts_page
        ).run!

        mail = described_class.with(
          canonical_pending_transaction_id: canonical_pending_transaction.id,
          canonical_transaction_id: canonical_transaction.id
        ).notify_settled

        expect(html_body(mail)).to include("A receipt has already been uploaded for this transaction.")
        expect(html_body(mail)).to include("manage your transaction here")
        expect(html_body(mail)).to include('alt="Receipt uploaded"')
        expect(html_body(mail)).not_to include("Click to upload your receipt")
        expect(html_body(mail)).not_to include("reply to this email with an image or PDF receipt attached")
      end
    end
  end
end
