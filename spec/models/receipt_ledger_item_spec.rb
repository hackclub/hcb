# frozen_string_literal: true

require "rails_helper"

# A transaction's receipts are attached to its ledger item
# (https://github.com/hackclub/hcb/issues/14106).
RSpec.describe Receipt, type: :model do
  def attach_receipt_to(receiptable, **attributes)
    receipt = Receipt.new(receiptable:, upload_method: :api, **attributes)
    receipt.file.attach(
      io: StringIO.new(File.binread(Rails.root.join("spec/fixtures/files/receipt.png"))),
      filename: "receipt.png", content_type: "image/png"
    )
    receipt.save!
    receipt
  end

  let(:hcb_code) { create(:canonical_pending_transaction).local_hcb_code.reload }
  let(:ledger_item) { hcb_code.ledger_item }

  describe "attaching to an HCB code" do
    it "lands on the code's ledger item instead" do
      receipt = attach_receipt_to(hcb_code)

      expect(receipt.reload.receiptable).to eq(ledger_item)
      expect(receipt.hcb_code).to eq(hcb_code)
      expect(hcb_code.receipts).to contain_exactly(receipt)
      expect(ledger_item.reload.receipt_count).to eq(1)
    end

    it "stays on a code that has no ledger item yet" do
      code_without_item = create(:hcb_code)

      receipt = attach_receipt_to(code_without_item)

      expect(receipt.reload.receiptable).to eq(code_without_item)
    end

    it "also applies when an existing receipt is linked to the code" do
      receipt = attach_receipt_to(nil, user: create(:user))

      receipt.update!(receiptable: hcb_code)

      expect(receipt.reload.receiptable).to eq(ledger_item)
    end

    it "clears the no/lost mark on both sides" do
      hcb_code.update!(marked_no_or_lost_receipt_at: 1.day.ago)
      ledger_item.update!(marked_no_or_lost_receipt_at: 1.day.ago)

      attach_receipt_to(hcb_code)

      expect(hcb_code.reload.marked_no_or_lost_receipt_at).to be_nil
      expect(ledger_item.reload.marked_no_or_lost_receipt_at).to be_nil
    end

    it "leaves other receiptables alone" do
      expense = create(:reimbursement_expense)

      expect(attach_receipt_to(expense).reload.receiptable).to eq(expense)
    end
  end

  describe ".reupload" do
    it "copies the receipts onto the ledger item" do
      expense = create(:reimbursement_expense)
      attach_receipt_to(expense, user: create(:user))

      Receipt.reupload(old_receiptable: expense, new_receiptable: hcb_code.ledger_item_or_self)

      expect(ledger_item.receipts.count).to eq(1)
      expect(ledger_item.receipts.sole.receiptable).to eq(ledger_item)
    end
  end

  describe "SuggestedPairing#mark_accepted!" do
    it "attaches the receipt to the ledger item" do
      receipt = attach_receipt_to(nil, user: create(:user))
      pairing = SuggestedPairing.create!(receipt:, hcb_code:, distance: 1)

      pairing.mark_accepted!

      expect(receipt.reload.receiptable).to eq(ledger_item)
      expect(hcb_code.receipts).to contain_exactly(receipt)
    end
  end

  describe "HcbCode#move_receipts_to_ledger_item!" do
    let(:code_without_item) { create(:hcb_code) }

    it "hands the code's receipts over when it is linked to a ledger item" do
      receipt = attach_receipt_to(code_without_item)
      expect(receipt.reload.receiptable).to eq(code_without_item)

      item = create(:ledger_item, hcb_code: code_without_item)

      expect(receipt.reload.receiptable).to eq(item)
      expect(item.reload.receipt_count).to eq(1)
      expect(code_without_item.reload.receipts).to contain_exactly(receipt)
    end

    it "doesn't run the receipt callbacks for a hand-over" do
      attach_receipt_to(code_without_item)

      expect { create(:ledger_item, hcb_code: code_without_item) }
        .not_to have_enqueued_job(Receipt::SuggestPairingsJob)
    end

    it "is a no-op for a code with no receipts or no ledger item" do
      expect(code_without_item.move_receipts_to_ledger_item!).to eq(0)

      item = create(:ledger_item, hcb_code: code_without_item)
      expect(code_without_item.reload.move_receipts_to_ledger_item!).to eq(0)
      expect(item.reload.receipt_count).to eq(0)
    end
  end

  describe "upload tasks" do
    include_context "card locking charges"

    it "are completed by a receipt attached to the ledger item" do
      charge = create_settled_card_charge(user:, settled_at: 3.days.ago)
      task = Task::Receiptable::Upload.create!(taskable: charge, assignee: user)
      expect(task.reload).not_to be_complete

      attach_receipt_to(charge.ledger_item, user:)

      expect(task.reload).to be_complete
    end

    it "reopen when the receipt is moved back to the receipt bin" do
      charge = create_settled_card_charge(user:, settled_at: 3.days.ago)
      task = Task::Receiptable::Upload.create!(taskable: charge, assignee: user)
      receipt = attach_receipt_to(charge.ledger_item, user:)
      expect(task.reload).to be_complete

      receipt.update!(receiptable: nil)

      expect(task.reload).not_to be_complete
    end
  end
end
