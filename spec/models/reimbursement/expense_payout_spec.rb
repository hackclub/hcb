# frozen_string_literal: true

require "rails_helper"

RSpec.describe Reimbursement::ExpensePayout do
  let(:event) { create(:event) }
  let(:report) { create(:reimbursement_report, event:) }

  def payout_for(expense)
    expense.update_column(:aasm_state, "approved")
    report.update_column(:aasm_state, "reimbursement_approved")

    described_class.create!(amount_cents: -expense.amount_cents, event:, expense:)
  end

  describe "the pending transaction's category" do
    it "is the expense's transaction category" do
      expense = create(:reimbursement_expense, report:, memo: "Flights", transaction_category_slug: "travel")

      payout = payout_for(expense)

      expect(payout.canonical_pending_transaction.category.slug).to eq("travel")
      expect(payout.canonical_pending_transaction.category_mapping).to be_automatic
    end

    it "is bank fees for a fee expense" do
      expense = create(:reimbursement_expense, report:, memo: "Wire fee", type: "Reimbursement::Expense::Fee")

      payout = payout_for(expense)

      expect(payout.canonical_pending_transaction.category.slug).to eq("bank-fees")
    end

    it "is left unset when the expense has no category" do
      expense = create(:reimbursement_expense, report:, memo: "Mystery")

      payout = payout_for(expense)

      expect(payout.canonical_pending_transaction.category).to be_nil
    end
  end
end
