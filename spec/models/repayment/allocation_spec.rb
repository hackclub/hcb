# frozen_string_literal: true

require "rails_helper"

RSpec.describe Repayment::Allocation do
  let(:requestor) { create(:user) }
  let(:source_event) { create(:event, :with_positive_balance) }
  let(:destination_event) { create(:event) }

  before { create(:organizer_position, event: source_event, user: requestor) }

  def repay(ledger_item, amount: "100.00")
    DisbursementService::Create.new(
      name: "Test",
      amount:,
      requested_by_id: requestor.id,
      source_event_id: source_event.id,
      destination_event_id: destination_event.id,
      transfer_type: "repayment",
      repaid_ledger_item_ids: [ledger_item.id]
    ).run
  end

  def payment(disbursement)
    disbursement.raw_pending_incoming_disbursement_transaction.canonical_pending_transaction
  end

  def splits(transaction)
    transaction.splits.reload.map { |split| [split.amount_cents, split.category.slug] }
  end

  describe "a repaid pending expense that settles" do
    # CTs and CPTs have separate id sequences and factory transactions fall back
    # to an `HCB-000-<id>` code, so pick an id no CT shares (see the same note
    # in spec/services/disbursement_service/create_spec.rb).
    let!(:pending_expense) { create(:canonical_pending_transaction, id: [CanonicalTransaction.maximum(:id).to_i, CanonicalPendingTransaction.maximum(:id).to_i].max + 1_000, event: destination_event, amount_cents: -100_00, category_slug: "food-fun") }
    let!(:disbursement) { repay(pending_expense.ledger_item) }

    def settle(amount_cents)
      create(:canonical_transaction, ledger_item: pending_expense.ledger_item, amount_cents:).tap do |settled|
        CanonicalPendingTransactionService::Settle.new(canonical_transaction: settled, canonical_pending_transaction: pending_expense).run!
        settled.reload
      end
    end

    it "stays a repayment in full, unsplit, when it settles for what was repaid" do
      settled = settle(-100_00)

      expect(settled.category.slug).to eq("repayment")
      expect(splits(settled) + splits(payment(disbursement))).to be_empty
    end

    it "splits off the repaid part and returns the rest to its own category when it settles for more" do
      settled = settle(-120_00)

      expect(pending_expense.ledger_item.reload.amount_cents).to eq(-120_00)
      expect(settled.category.slug).to eq("food-fun")
      expect(splits(settled)).to eq([[-100_00, "repayment"]])
      expect(settled.splits.sole.memo).to eq("Repaid by #{source_event.name}")
      expect(splits(payment(disbursement))).to be_empty
    end

    it "splits what the payment overpaid into an internal transfer when it settles for less" do
      settled = settle(-80_00)

      expect(settled.category.slug).to eq("repayment")
      expect(splits(settled)).to be_empty
      expect(splits(payment(disbursement))).to eq([[20_00, "internal-transfer"]])
    end

    it "puts everything back when the repayment is rejected" do
      settled = settle(-120_00)
      disbursement.mark_rejected!(create(:user, :make_admin))

      expect(settled.reload.category.slug).to eq("food-fun")
      expect(TransactionSplit.count).to eq(0)
    end
  end

  describe "a repaid settled expense" do
    let!(:expense) { create(:canonical_transaction, event: destination_event, amount_cents: -100_00, category_slug: "food-fun") }
    let!(:disbursement) { repay(expense.ledger_item) }

    it "splits what the payment overpaid into an internal transfer when part of it is refunded" do
      create(:canonical_transaction, ledger_item: expense.ledger_item, amount_cents: 30_00)

      expect(expense.ledger_item.reload.amount_cents).to eq(-70_00)
      expect(expense.reload.category.slug).to eq("repayment")
      expect(splits(payment(disbursement))).to eq([[30_00, "internal-transfer"]])
    end

    it "re-splits as the amount keeps changing" do
      create(:canonical_transaction, ledger_item: expense.ledger_item, amount_cents: -50_00)
      expect(splits(expense)).to eq([[-100_00, "repayment"]])
      expect(expense.reload.category.slug).to eq("food-fun")

      create(:canonical_transaction, ledger_item: expense.ledger_item, amount_cents: 50_00)
      expect(splits(expense)).to be_empty
      expect(expense.reload.category.slug).to eq("repayment")
    end
  end
end
