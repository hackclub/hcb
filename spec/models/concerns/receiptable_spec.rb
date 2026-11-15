# frozen_string_literal: true

require "rails_helper"

# A transaction's receipts live on its ledger item
# (https://github.com/hackclub/hcb/issues/14106); the HCB code reads them
# through the item.
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

  # A receipt row still pointing at the HCB code, the way the ones the backfill
  # skips (codes with no ledger item) do.
  def leave_receipt_on(hcb_code)
    attach_receipt_to(hcb_code.ledger_item).tap do |receipt|
      receipt.update_columns(receiptable_type: "HcbCode", receiptable_id: hcb_code.id)
    end
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
    it "reads the ledger item's receipts from the HCB code" do
      receipt = attach_receipt_to(ledger_item)

      expect(ledger_item.receipts).to contain_exactly(receipt)
      expect(hcb_code.receipts).to contain_exactly(receipt)
    end

    it "is chainable like the association it replaces" do
      receipt = attach_receipt_to(ledger_item, user: create(:user))

      expect(hcb_code.receipts.with_attached_file.includes(:user).order(created_at: :asc)).to eq([receipt])
      expect(hcb_code.receipts.where(data_extracted: true)).to be_empty
    end

    it "answers from the preloaded association without querying" do
      attach_receipt_to(ledger_item)

      loaded = HcbCode.includes(:receipts).find(hcb_code.id)

      queries = count_queries do
        expect(loaded.receipts.size).to eq(1)
        expect(loaded).not_to be_without_receipt
      end
      expect(queries).to eq(0)
    end

    it "is read-only on the HCB code; receipts are attached to the ledger item" do
      receipt = Receipt.new(upload_method: :api, user: create(:user))
      receipt.file.attach(
        io: StringIO.new(File.binread(Rails.root.join("spec/fixtures/files/receipt.png"))),
        filename: "receipt.png", content_type: "image/png"
      )

      expect { hcb_code.receipts << receipt }.to raise_error(ActiveRecord::HasManyThroughCantAssociateThroughHasOneOrManyReflection)
    end

    it "reads nothing from an HCB code with no ledger item" do
      code_without_item = create(:hcb_code)

      expect(code_without_item.ledger_item).to be_nil
      expect(code_without_item.receipts).to be_empty
    end

    it "no longer surfaces a receipt row left on the HCB code itself" do
      leave_receipt_on(hcb_code)

      expect(hcb_code.receipts).to be_empty
      expect(ledger_item.receipts).to be_empty
    end

    it "leaves every other receiptable on its own association" do
      expense = create(:reimbursement_expense)
      receipt = attach_receipt_to(expense)

      expect(expense.receipts).to be_a(ActiveRecord::Associations::CollectionProxy)
      expect(expense.receipts).to contain_exactly(receipt)
    end
  end

  describe "#without_receipt?" do
    it "is false on both sides once the ledger item has a receipt" do
      attach_receipt_to(ledger_item)

      expect(hcb_code).not_to be_without_receipt
      expect(ledger_item.reload).not_to be_without_receipt
    end

    it "is true on both sides when the ledger item has none" do
      expect(hcb_code).to be_without_receipt
      expect(ledger_item).to be_without_receipt
    end
  end

  describe "receipt scopes" do
    it "treat the ledger item's receipt as the HCB code's" do
      attach_receipt_to(ledger_item)

      expect(HcbCode.with_receipt).to include(hcb_code)
      expect(HcbCode.has_receipt_or_marked_no_or_lost).to include(hcb_code)
      expect(HcbCode.without_receipt).not_to include(hcb_code)
      expect(HcbCode.missing_receipt).not_to include(hcb_code)
    end

    it "report an HCB code whose ledger item has no receipt as missing one" do
      expect(HcbCode.without_receipt).to include(hcb_code)
      expect(HcbCode.missing_receipt).to include(hcb_code)
      expect(HcbCode.with_receipt).not_to include(hcb_code)
    end

    it "ignore a receipt row left on the HCB code itself" do
      leave_receipt_on(hcb_code)

      expect(HcbCode.with_receipt).not_to include(hcb_code)
      expect(HcbCode.without_receipt).to include(hcb_code)
    end

    it "keep working for receiptables that hold their own receipts" do
      with_receipt = create(:reimbursement_expense)
      attach_receipt_to(with_receipt)
      without_receipt = create(:reimbursement_expense)

      expect(Reimbursement::Expense.with_receipt).to include(with_receipt)
      expect(Reimbursement::Expense.with_receipt).not_to include(without_receipt)
      expect(Reimbursement::Expense.without_receipt).to include(without_receipt)
    end
  end

  describe "Ledger::Item#receipt_count" do
    it "counts a receipt attached to the item" do
      attach_receipt_to(ledger_item)

      expect(ledger_item.reload.receipt_count).to eq(1)
    end

    it "drops back when the receipt is destroyed" do
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
    it "is the item's HCB code for a ledger item" do
      expect(attach_receipt_to(ledger_item).hcb_code).to eq(hcb_code)
    end

    it "is the receiptable itself for a receipt still on an HCB code" do
      code_without_item = create(:hcb_code)

      expect(attach_receipt_to(code_without_item).hcb_code).to eq(code_without_item)
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

    it "resolves a charge with a receipt attached to it" do
      charge = create_settled_card_charge(user:, settled_at: 5.days.ago)
      travel_to(2.days.ago) { attach_receipt_to(charge, user:) }

      expect(charge.reload.card_locking_resolved_at).to be_within(1.second).of(2.days.ago)
      expect(Ledger::Item.card_locking_candidates).not_to include(charge)
    end

    it "resolves the same way from the preloaded association, without querying" do
      charge = create_settled_card_charge(user:, settled_at: 5.days.ago)
      travel_to(2.days.ago) { attach_receipt_to(charge, user:) }

      loaded = Ledger::Item.includes(:receipts).find(charge.id)

      queries = count_queries do
        expect(loaded.card_locking_resolved_at).to be_within(1.second).of(2.days.ago)
      end
      expect(queries).to eq(0)
    end

    it "still lists a charge with no receipt as a candidate" do
      charge = create_settled_card_charge(user:, settled_at: 5.days.ago)

      expect(Ledger::Item.card_locking_candidates).to include(charge)
    end
  end
end
