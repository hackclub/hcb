# frozen_string_literal: true

require "rails_helper"

RSpec.describe PendingTransactionEngine::PendingTransaction::All do
  describe "#run with missing_receipts" do
    let(:event) { create(:event) }

    def pending_expense
      cpt = create(:canonical_pending_transaction, amount_cents: -1000)
      create(:canonical_pending_event_mapping, canonical_pending_transaction: cpt, event:)
      cpt
    end

    def attach_receipt_to(receiptable)
      receipt = Receipt.new(receiptable:, upload_method: :api)
      receipt.file.attach(
        io: StringIO.new(File.binread(Rails.root.join("spec/fixtures/files/receipt.png"))),
        filename: "receipt.png", content_type: "image/png"
      )
      receipt.save!
    end

    def missing_receipts
      described_class.new(event_id: event.id, missing_receipts: true).run
    end

    it "includes an expense with no receipt" do
      cpt = pending_expense

      expect(missing_receipts).to include(cpt)
    end

    it "excludes an expense whose receipt is on its HCB code" do
      cpt = pending_expense
      attach_receipt_to(cpt.local_hcb_code)

      expect(missing_receipts).not_to include(cpt)
    end

    # Receipts are moving onto ledger items (#14106); the filter has to see them
    # on either side.
    it "excludes an expense whose receipt is on its ledger item" do
      cpt = pending_expense
      attach_receipt_to(cpt.local_hcb_code.reload.ledger_item)

      expect(missing_receipts).not_to include(cpt)
    end

    it "excludes an expense marked no/lost receipt" do
      cpt = pending_expense
      cpt.local_hcb_code.no_or_lost_receipt!

      expect(missing_receipts).not_to include(cpt)
    end
  end
end
