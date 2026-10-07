# frozen_string_literal: true

require "rails_helper"

RSpec.describe PendingEventMappingEngine::Nightly do
  describe "settling expense payouts" do
    let(:event) { create(:event) }
    let(:report) { create(:reimbursement_report, event:) }
    let(:expense) { create(:reimbursement_expense, report:, memo: "Wire fee", type: "Reimbursement::Expense::Fee") }

    let!(:payout) do
      expense.update_column(:aasm_state, "approved")
      report.update_column(:aasm_state, "reimbursement_approved")

      Reimbursement::ExpensePayout.create!(amount_cents: -expense.amount_cents, event:, expense:)
    end

    let!(:canonical_transaction) do
      create(:canonical_transaction, amount_cents: payout.amount_cents).tap do |ct|
        ct.update_column(:hcb_code, payout.hcb_code)
      end
    end

    it "copies the pending transaction's category to the settled transaction" do
      cpt = payout.canonical_pending_transaction
      expect(cpt.category.slug).to eq("bank-fees")

      described_class.new.send(:settle_canonical_pending_expense_payout!)

      expect(cpt.reload.canonical_transactions).to contain_exactly(canonical_transaction)
      expect(canonical_transaction.reload.category.slug).to eq("bank-fees")
      expect(canonical_transaction.category_mapping).to be_automatic
    end
  end
end
