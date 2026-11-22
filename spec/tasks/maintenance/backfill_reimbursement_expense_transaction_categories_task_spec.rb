# frozen_string_literal: true

require "rails_helper"

RSpec.describe Maintenance::BackfillReimbursementExpenseTransactionCategoriesTask do
  let(:event) { create(:event) }
  let(:report) { create(:reimbursement_report, event:) }

  def payout_for(expense)
    expense.update_column(:aasm_state, "approved")
    report.update_column(:aasm_state, "reimbursement_approved")

    Reimbursement::ExpensePayout.create!(amount_cents: -expense.amount_cents, event:, expense:)
  end

  it "maps every legacy category to a transaction category" do
    expect(described_class::LEGACY_CATEGORY_SLUGS.keys).to match_array(Reimbursement::Expense.categories.keys)
    expect(described_class::LEGACY_CATEGORY_SLUGS.values).to all(be_in(TransactionCategory::Definition::ALL.keys))
  end

  it "collects expenses with a legacy category and no transaction category" do
    legacy = create(:reimbursement_expense, report:, category: "Travel")
    migrated = create(:reimbursement_expense, report:, category: "Travel", transaction_category_slug: "travel")
    new_style = create(:reimbursement_expense, report:, transaction_category_slug: "travel")
    uncategorized = create(:reimbursement_expense, report:)

    expect(described_class.collection).to contain_exactly(legacy)
    expect(described_class.collection).not_to include(migrated, new_style, uncategorized)
  end

  it "sets the transaction category without resetting the expense's approval" do
    expense = create(:reimbursement_expense, report:, memo: "Hotel", category: "Travel")
    expense.update_column(:aasm_state, "approved")

    described_class.process(expense)

    expect(expense.reload.transaction_category_slug).to eq("travel")
    expect(expense).to be_approved
  end

  it "categorizes the payout's pending transaction and the transactions settled from it" do
    expense = create(:reimbursement_expense, report:, memo: "Pizza", category: "Food & Entertainment")
    payout = payout_for(expense)
    expect(payout.canonical_pending_transaction.category).to be_nil
    settled = create(:canonical_transaction, amount_cents: payout.amount_cents).tap do |ct|
      ct.update_column(:hcb_code, payout.hcb_code)
    end

    described_class.process(expense)

    expect(payout.canonical_pending_transaction.reload.category.slug).to eq("food-fun")
    expect(payout.canonical_pending_transaction.category_mapping).to be_automatic
    expect(settled.reload.category.slug).to eq("food-fun")
  end

  it "leaves a transaction's existing category alone" do
    expense = create(:reimbursement_expense, report:, memo: "Pizza", category: "Food & Entertainment")
    payout = payout_for(expense)
    settled = create(:canonical_transaction, amount_cents: payout.amount_cents).tap do |ct|
      ct.update_column(:hcb_code, payout.hcb_code)
    end
    TransactionCategoryService.new(model: settled).set!(slug: "travel", assignment_strategy: "manual")

    described_class.process(expense)

    expect(payout.canonical_pending_transaction.reload.category.slug).to eq("food-fun")
    expect(settled.reload.category.slug).to eq("travel")
  end
end
