# frozen_string_literal: true

require "rails_helper"

RSpec.describe SuggestedPairing, type: :model do
  describe "#mark_accepted!" do
    it "attaches the receipt to the transaction's ledger item" do
      hcb_code = create(:canonical_pending_transaction).local_hcb_code
      receipt = Receipt.new(user: create(:user), upload_method: :api)
      receipt.file.attach(io: File.open(file_fixture("receipt.png")), filename: "receipt.png", content_type: "image/png")
      receipt.save!
      pairing = described_class.create!(receipt:, hcb_code:, ledger_item: hcb_code.ledger_item, distance: 1)

      pairing.mark_accepted!

      expect(receipt.reload.receiptable).to eq(hcb_code.ledger_item)
      expect(hcb_code.receipts).to contain_exactly(receipt)
    end
  end
end
