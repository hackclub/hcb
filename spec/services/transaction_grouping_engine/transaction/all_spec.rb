# frozen_string_literal: true

require "rails_helper"

RSpec.describe TransactionGroupingEngine::Transaction::All do
  describe "#run" do
    it "returns an empty array if there are no transactions" do
      event = create(:event)

      expect(described_class.new(event_id: event.id).run).to be_empty
    end

    it "returns transactions for the given event" do
      events = create_list(:event, 2)

      events.each do |event|
        ["transaction_1", "transaction_2"].each do |memo|
          create(
            :canonical_event_mapping,
            event: event,
            canonical_transaction: create(:canonical_transaction, memo:)
          )
        end
      end

      results = described_class.new(event_id: events.first.id).run
      expect(results.size).to eq(2)
      expect(results.map(&:event)).to all(eq(events.first))
      expect(results.map(&:memo)).to contain_exactly("TRANSACTION_1", "TRANSACTION_2")
    end

    it "allows filtering by memo" do
      event = create(:event)

      snack = create(
        :canonical_transaction,
        memo: "SHELBURNE MARKET",
        custom_memo: "Snacks at Shelburne Market"
      )
      create(:canonical_event_mapping, event: event, canonical_transaction: snack)

      sharks = create(
        :canonical_transaction,
        memo: "IKEA 111111111",
        custom_memo: "A shiver of Blåhaj"
      )
      create(:canonical_event_mapping, event: event, canonical_transaction: sharks)

      ["snAck", "mARKet"].each do |search|
        result = described_class.new(event_id: event.id, search:).all.sole
        expect(JSON.parse(result.raw_canonical_transaction_ids)).to contain_exactly(snack.id)
      end

      ["shiver", "IKEA"].each do |search|
        result = described_class.new(event_id: event.id, search:).all.sole
        expect(JSON.parse(result.raw_canonical_transaction_ids)).to contain_exactly(sharks.id)
      end
    end

    it "escapes the search string" do
      event = create(:event)

      transaction = create(
        :canonical_transaction,
        memo: "; DROP TABLE",
        custom_memo: "%%%LOL%%%:oops ?"
      )
      create(:canonical_event_mapping, event: event, canonical_transaction: transaction)

      [":oops ?", "%%%lol"].each do |search|
        result = described_class.new(event_id: event.id, search:).all.sole
        expect(JSON.parse(result.raw_canonical_transaction_ids)).to contain_exactly(transaction.id)
      end
    end
  end

  describe "#run with missing_receipts" do
    let(:event) { create(:event) }

    def settled_expense
      ct = create(:canonical_transaction, amount_cents: -1000)
      create(:canonical_event_mapping, event:, canonical_transaction: ct)
      ct
    end

    def attach_receipt_to(receiptable)
      receipt = Receipt.new(receiptable:, upload_method: :api)
      receipt.file.attach(
        io: StringIO.new(File.binread(Rails.root.join("spec/fixtures/files/receipt.png"))),
        filename: "receipt.png", content_type: "image/png"
      )
      receipt.save!
    end

    def missing_receipt_codes
      described_class.new(event_id: event.id, missing_receipts: true).run.map(&:hcb_code)
    end

    it "includes an expense with no receipt" do
      ct = settled_expense

      expect(missing_receipt_codes).to include(ct.hcb_code)
    end

    # Receipts are attached to the ledger item (#14106); the filter reads them
    # through the HCB code's ledger_item_id.
    it "excludes an expense whose receipt is on its ledger item" do
      ct = settled_expense
      attach_receipt_to(ct.local_hcb_code.reload.ledger_item)

      expect(missing_receipt_codes).not_to include(ct.hcb_code)
    end
  end
end
