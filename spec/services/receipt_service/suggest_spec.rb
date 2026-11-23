# frozen_string_literal: true

require "rails_helper"

RSpec.describe ReceiptService::Suggest do
  let(:user) { create(:user) }
  let(:event) { create(:event) }
  let(:stripe_card) { create(:stripe_card, :with_stripe_id, stripe_cardholder: create(:stripe_cardholder, user:), event:) }

  # A pending card charge on the user's card, missing its receipt.
  def create_pending_card_charge(amount_cents: -12_34)
    raw_pending_stripe_transaction = create(:raw_pending_stripe_transaction, stripe_card:, amount_cents:)
    canonical_pending_transaction = create(:canonical_pending_transaction, raw_pending_stripe_transaction:, amount_cents:, event:)
    canonical_pending_transaction.local_hcb_code.reload
  end

  def create_receipt_in_bin
    receipt = Receipt.new(user:, upload_method: :email_receipt_bin)
    receipt.file.attach(io: File.open(file_fixture("receipt.png")), filename: "receipt.png", content_type: "image/png")
    receipt.save!
    receipt
  end

  describe "#run!" do
    let(:receipt) { create_receipt_in_bin }

    before do
      # The suggestions are scored against what the extractor read off the
      # receipt; the extraction itself (OCR and an LLM call) is out of scope.
      allow(receipt).to receive(:has_textual_content?).and_return(true)
      allow(ReceiptService::Extract).to receive(:new).with(receipt:).and_return(instance_double(ReceiptService::Extract, run!: receipt))
    end

    it "writes a pairing with the charge's ledger item" do
      hcb_code = create_pending_card_charge
      allow(user).to receive(:card_charges_missing_receipt).and_return(Ledger::Item.where(id: hcb_code.ledger_item_id))

      described_class.new(receipt:).run!

      pairing = SuggestedPairing.find_by!(receipt:, ledger_item: hcb_code.ledger_item)
      expect(pairing).to be_unreviewed
    end

    it "rescores a pairing it already wrote rather than duplicating it" do
      hcb_code = create_pending_card_charge
      allow(user).to receive(:card_charges_missing_receipt).and_return(Ledger::Item.where(id: hcb_code.ledger_item_id))

      2.times { described_class.new(receipt:).run! }

      expect(SuggestedPairing.where(receipt:).count).to eq(1)
    end

    it "pairs the receipt automatically when a charge matches closely" do
      hcb_code = create_pending_card_charge(amount_cents: -12_34)
      receipt.update!(extracted_total_amount_cents: 12_34, extracted_card_last4: stripe_card.last4,
                      extracted_date: hcb_code.date, extracted_merchant_name: "merchant 1")
      allow(user).to receive(:card_charges_missing_receipt).and_return(Ledger::Item.where(id: hcb_code.ledger_item_id))

      pairing = described_class.new(receipt:).run!

      expect(pairing).to be_accepted
      expect(receipt.reload.receiptable).to eq(hcb_code.ledger_item)
    end
  end
end
