# frozen_string_literal: true

require "rails_helper"

# Receipts are moving from HCB codes onto their ledger items
# (https://github.com/hackclub/hcb/issues/14106). Until the backfill has run a
# transaction's receipts can sit on either record, so both sides read both.
RSpec.describe Receiptable do
  def attach_receipt_to(receiptable, **attributes)
    receipt = Receipt.new(receiptable:, upload_method: :api, **attributes)
    receipt.file.attach(
      io: StringIO.new(File.binread(Rails.root.join("spec/fixtures/files/receipt.png"))),
      filename: "receipt.png", content_type: "image/png"
    )
    receipt.save!
    receipt
  end

  def count_queries
    count = 0
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      count += 1 unless payload[:name] == "SCHEMA"
    end
    yield
    count
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end

  # A pending transaction builds and links its HCB code's ledger item.
  let(:hcb_code) { create(:canonical_pending_transaction).local_hcb_code.reload }
  let(:ledger_item) { hcb_code.ledger_item }

  describe "#receipts" do
    it "reads a receipt attached to the ledger item from the HCB code" do
      receipt = attach_receipt_to(ledger_item)

      expect(hcb_code.receipts).to contain_exactly(receipt)
    end

    it "reads a receipt attached to the HCB code from the ledger item" do
      receipt = attach_receipt_to(hcb_code)

      expect(ledger_item.receipts).to contain_exactly(receipt)
    end

    it "reads receipts split across the two sides from both" do
      on_code = attach_receipt_to(hcb_code)
      on_item = attach_receipt_to(ledger_item)

      expect(hcb_code.receipts).to contain_exactly(on_code, on_item)
      expect(ledger_item.receipts).to contain_exactly(on_code, on_item)
    end

    it "is chainable like the association it replaces" do
      receipt = attach_receipt_to(ledger_item, user: create(:user))

      expect(hcb_code.receipts.with_attached_file.includes(:user).order(created_at: :asc)).to eq([receipt])
      expect(hcb_code.receipts.where(data_extracted: true)).to be_empty
    end

    it "reads only the HCB code's own receipts when it has no ledger item yet" do
      code_without_item = create(:hcb_code)
      receipt = attach_receipt_to(code_without_item)

      expect(code_without_item.receipts).to contain_exactly(receipt)
    end

    it "leaves every other receiptable on its own association" do
      expense = create(:reimbursement_expense)
      receipt = attach_receipt_to(expense)

      expect(expense.receipts).to be_a(ActiveRecord::Associations::CollectionProxy)
      expect(expense.receipts).to contain_exactly(receipt)
    end
  end

  describe "#without_receipt?" do
    it "is false when the only receipt is on the other side" do
      attach_receipt_to(ledger_item)

      expect(hcb_code).not_to be_without_receipt
      expect(ledger_item.reload).not_to be_without_receipt
    end

    it "is true when neither side has a receipt" do
      expect(hcb_code).to be_without_receipt
      expect(ledger_item).to be_without_receipt
    end
  end

  describe "#preloaded_receipts and #receipts_count" do
    it "answer from the preloaded associations without querying" do
      on_code = attach_receipt_to(hcb_code)
      on_item = attach_receipt_to(ledger_item)

      loaded = HcbCode.includes(:receipts, ledger_item: :receipts).find(hcb_code.id)

      queries = count_queries do
        expect(loaded.preloaded_receipts).to contain_exactly(on_code, on_item)
        expect(loaded.receipts_count).to eq(2)
        expect(loaded).not_to be_without_receipt
      end
      expect(queries).to eq(0)
    end

    it "fall back to a query when only one side was preloaded" do
      attach_receipt_to(ledger_item)

      loaded = HcbCode.includes(:receipts).find(hcb_code.id)

      expect(loaded.preloaded_receipts).to be_nil
      expect(loaded.receipts_count).to eq(1)
    end

    it "fall back to a query when nothing was preloaded" do
      attach_receipt_to(hcb_code)

      expect(hcb_code.preloaded_receipts).to be_nil
      expect(hcb_code.receipts_count).to eq(1)
    end
  end

  describe "receipt scopes" do
    it "treat a receipt on the ledger item as the HCB code's" do
      attach_receipt_to(ledger_item)

      expect(HcbCode.with_receipt).to include(hcb_code)
      expect(HcbCode.has_receipt_or_marked_no_or_lost).to include(hcb_code)
      expect(HcbCode.without_receipt).not_to include(hcb_code)
      expect(HcbCode.missing_receipt).not_to include(hcb_code)
    end

    it "treat a receipt on the HCB code as before" do
      attach_receipt_to(hcb_code)

      expect(HcbCode.with_receipt).to include(hcb_code)
      expect(HcbCode.missing_receipt).not_to include(hcb_code)
    end

    it "report an HCB code with no receipt on either side as missing one" do
      expect(HcbCode.without_receipt).to include(hcb_code)
      expect(HcbCode.missing_receipt).to include(hcb_code)
      expect(HcbCode.with_receipt).not_to include(hcb_code)
    end

    it "keep working for receiptables that only hold their own receipts" do
      with_receipt = create(:reimbursement_expense)
      attach_receipt_to(with_receipt)
      without_receipt = create(:reimbursement_expense)

      expect(Reimbursement::Expense.with_receipt).to include(with_receipt)
      expect(Reimbursement::Expense.with_receipt).not_to include(without_receipt)
      expect(Reimbursement::Expense.without_receipt).to include(without_receipt)
    end
  end

  describe "Ledger::Item#receipt_count" do
    it "counts a receipt attached to the item itself" do
      attach_receipt_to(ledger_item)

      expect(ledger_item.reload.receipt_count).to eq(1)
    end

    it "counts a receipt attached to the HCB code" do
      attach_receipt_to(hcb_code)

      expect(ledger_item.reload.receipt_count).to eq(1)
    end

    it "drops back when a receipt attached to the item is destroyed" do
      receipt = attach_receipt_to(ledger_item)
      expect(ledger_item.reload.receipt_count).to eq(1)

      receipt.destroy!

      expect(ledger_item.reload.receipt_count).to eq(0)
    end
  end

  describe "the no/lost receipt mark" do
    before do
      hcb_code.update!(marked_no_or_lost_receipt_at: 1.day.ago)
      ledger_item.update!(marked_no_or_lost_receipt_at: 1.day.ago)
    end

    it "is cleared on both sides by a receipt attached to the HCB code" do
      attach_receipt_to(hcb_code)

      expect(hcb_code.reload.marked_no_or_lost_receipt_at).to be_nil
      expect(ledger_item.reload.marked_no_or_lost_receipt_at).to be_nil
    end

    it "is cleared on both sides by a receipt attached to the ledger item" do
      attach_receipt_to(ledger_item)

      expect(hcb_code.reload.marked_no_or_lost_receipt_at).to be_nil
      expect(ledger_item.reload.marked_no_or_lost_receipt_at).to be_nil
    end

    it "is cleared on both sides by ReceiptService::Create" do
      ::ReceiptService::Create.new(
        receiptable: ledger_item,
        uploader: create(:user),
        attachments: [fixture_file_upload("receipt.png", "image/png")],
        upload_method: :api
      ).run!

      expect(hcb_code.reload.marked_no_or_lost_receipt_at).to be_nil
      expect(ledger_item.reload.marked_no_or_lost_receipt_at).to be_nil
    end
  end

  describe "Receipt#hcb_code" do
    it "is the receiptable itself for an HCB code" do
      expect(attach_receipt_to(hcb_code).hcb_code).to eq(hcb_code)
    end

    it "is the item's HCB code for a ledger item" do
      expect(attach_receipt_to(ledger_item).hcb_code).to eq(hcb_code)
    end

    it "is nil for other receiptables and in the receipt bin" do
      expect(attach_receipt_to(create(:reimbursement_expense)).hcb_code).to be_nil
      expect(attach_receipt_to(nil, user: create(:user)).hcb_code).to be_nil
    end

    it "is nil for a canonical transaction, even though it has a local HCB code" do
      canonical_transaction = create(:canonical_transaction)
      expect(canonical_transaction.local_hcb_code).to be_present

      expect(attach_receipt_to(canonical_transaction).hcb_code).to be_nil
    end
  end

  describe "card locking" do
    include_context "card locking charges"

    let(:now) { Time.zone.parse("2026-10-10 12:00:00") }

    around do |ex|
      travel_to(now)
      ex.run
    ensure
      travel_back
    end

    it "resolves a charge with a receipt attached to its ledger item" do
      charge = create_settled_card_charge(user:, settled_at: 5.days.ago)
      travel_to(2.days.ago) { attach_receipt_to(charge.ledger_item, user:) }

      expect(charge.reload.card_locking_resolved_at).to be_within(1.second).of(2.days.ago)
      expect(HcbCode.card_locking_candidates).not_to include(charge)
    end

    it "resolves the same way from the preloaded associations" do
      charge = create_settled_card_charge(user:, settled_at: 5.days.ago)
      travel_to(2.days.ago) { attach_receipt_to(charge.ledger_item, user:) }

      loaded = HcbCode.includes(:receipts, ledger_item: :receipts).find(charge.id)

      expect(loaded.preloaded_receipts).to be_present
      expect(loaded.card_locking_resolved_at).to be_within(1.second).of(2.days.ago)
    end

    it "still lists a charge with no receipt on either side as a candidate" do
      charge = create_settled_card_charge(user:, settled_at: 5.days.ago)

      expect(HcbCode.card_locking_candidates).to include(charge)
    end
  end
end
