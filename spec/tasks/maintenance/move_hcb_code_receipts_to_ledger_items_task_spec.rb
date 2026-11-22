# frozen_string_literal: true

require "rails_helper"

RSpec.describe Maintenance::MoveHcbCodeReceiptsToLedgerItemsTask do
  include ActiveJob::TestHelper

  # Receipt's before_validation sends a new receipt to the ledger item, so put
  # one on the HCB code the way the rows this task is for got there: before the
  # move, with the raw columns.
  def receipt_left_on(hcb_code)
    receipt = Receipt.new(receiptable: hcb_code, upload_method: :api)
    receipt.file.attach(
      io: StringIO.new(File.binread(Rails.root.join("spec/fixtures/files/receipt.png"))),
      filename: "receipt.png", content_type: "image/png"
    )
    receipt.save!
    receipt.update_columns(receiptable_type: "HcbCode", receiptable_id: hcb_code.id)
    receipt
  end

  def hcb_code_with_ledger_item
    create(:canonical_pending_transaction).local_hcb_code.reload
  end

  describe "#collection" do
    it "holds the HCB codes that still have a receipt of their own and a ledger item" do
      with_receipt = hcb_code_with_ledger_item
      receipt_left_on(with_receipt)
      without_receipt = hcb_code_with_ledger_item
      moved_already = hcb_code_with_ledger_item
      receipt_left_on(moved_already).update_columns(receiptable_type: "Ledger::Item", receiptable_id: moved_already.ledger_item_id)

      expect(described_class.new.collection).to include(with_receipt)
      expect(described_class.new.collection).not_to include(without_receipt, moved_already)
    end

    it "leaves an HCB code with no ledger item alone" do
      orphan = create(:hcb_code)
      receipt = receipt_left_on(orphan)

      expect(described_class.new.collection).not_to include(orphan)
      expect(receipt.reload.receiptable).to eq(orphan)
    end
  end

  describe "#process" do
    it "moves the code's receipts onto its ledger item and refreshes the item's count" do
      hcb_code = hcb_code_with_ledger_item
      receipts = [receipt_left_on(hcb_code), receipt_left_on(hcb_code)]
      hcb_code.ledger_item.update_column(:receipt_count, 0)

      described_class.new.process(hcb_code)

      expect(receipts.map { |receipt| receipt.reload.receiptable }).to all(eq(hcb_code.ledger_item))
      expect(hcb_code.ledger_item.reload.receipt_count).to eq(2)
      expect(hcb_code.reload.receipts).to match_array(receipts)
    end

    it "doesn't run the receipt callbacks for the moved rows" do
      hcb_code = hcb_code_with_ledger_item
      receipt_left_on(hcb_code)

      expect { described_class.new.process(hcb_code) }.not_to have_enqueued_job(Receipt::SuggestPairingsJob)
      expect { described_class.new.process(hcb_code) }.not_to have_enqueued_job(User::UpdateCardLockingJob)
    end

    it "is idempotent" do
      hcb_code = hcb_code_with_ledger_item
      receipt_left_on(hcb_code)
      described_class.new.process(hcb_code)

      expect { described_class.new.process(hcb_code.reload) }.not_to(change { Receipt.order(:id).pluck(:receiptable_type, :receiptable_id) })
    end
  end
end
