# frozen_string_literal: true

require "rails_helper"

RSpec.describe User::ReceiptBin do
  let(:user) { create(:user) }

  def create_receipt_in_bin
    receipt = Receipt.new(user:, upload_method: :api)
    receipt.file.attach(io: File.open(file_fixture("receipt.png")), filename: "receipt.png", content_type: "image/png")
    receipt.save!
    receipt
  end

  def create_pairing(receipt, hcb_code, distance: 10)
    SuggestedPairing.create!(receipt:, hcb_code:, ledger_item: hcb_code.ledger_item, distance:)
  end

  describe "#suggested_receipt_pairings" do
    it "suggests the closest pairing for each receipt whose ledger item is still missing a receipt" do
      hcb_code = create(:canonical_pending_transaction, amount_cents: -10_00).local_hcb_code
      hcb_code.ledger_item.update_columns(receipt_required: true, receipt_count: 0)
      receipt = create_receipt_in_bin
      create_pairing(receipt, hcb_code, distance: 30)
      closest = create_pairing(receipt, create(:canonical_pending_transaction, amount_cents: -10_00).local_hcb_code, distance: 5)
      closest.ledger_item.update_columns(receipt_required: true, receipt_count: 0)

      expect(user.receipt_bin.suggested_receipt_pairings).to eq([closest])
    end

    it "leaves out pairings whose ledger item already has a receipt, and pairings without a ledger item" do
      receipted = create(:canonical_pending_transaction, amount_cents: -10_00).local_hcb_code
      receipted.ledger_item.update_columns(receipt_required: true, receipt_count: 1)
      create_pairing(create_receipt_in_bin, receipted)
      orphan = create(:canonical_pending_transaction, amount_cents: -10_00).local_hcb_code
      orphan.ledger_item.update_columns(receipt_required: true, receipt_count: 0)
      create_pairing(create_receipt_in_bin, orphan).update_column(:ledger_item_id, nil)

      expect(user.receipt_bin.suggested_receipt_pairings).to be_empty
    end
  end
end
