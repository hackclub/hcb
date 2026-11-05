# frozen_string_literal: true

require "rails_helper"

RSpec.describe RepaymentService::Mark do
  let(:event) { create(:event) }
  let(:user) { create(:user) }
  let(:expense) { create(:canonical_transaction, event:, amount_cents: -100_00, memo: "Pizza", category_slug: "food-fun") }
  let(:income) { create(:canonical_transaction, event:, amount_cents: 100_00, memo: "Venmo from Sam") }

  def mark(from, to)
    described_class.new(ledger_item: from.ledger_item.reload, other_ledger_item_hashid: to.ledger_item.reload.hashid, created_by: user).run
  end

  it "marks income as repaying an expense" do
    repayment = mark(income, expense)

    expect(repayment).to be_persisted
    expect(repayment.repaid_ledger_item).to eq(expense.ledger_item)
    expect(repayment.repaying_ledger_item).to eq(income.ledger_item)
    expect(repayment.amount_cents).to eq(100_00)
    expect(repayment.created_by).to eq(user)
  end

  it "marks an expense as repaid by income" do
    repayment = mark(expense, income)

    expect(repayment.repaid_ledger_item).to eq(expense.ledger_item)
    expect(repayment.repaying_ledger_item).to eq(income.ledger_item)
  end

  it "categorizes both sides as a repayment" do
    mark(income, expense)

    expect(expense.reload.category.slug).to eq(Repayment::CATEGORY_SLUG)
    expect(income.reload.category.slug).to eq(Repayment::CATEGORY_SLUG)
  end

  it "won't match two expenses" do
    other_expense = create(:canonical_transaction, event:, amount_cents: -100_00)

    expect { mark(expense, other_expense) }.to raise_error(described_class::UserError, "That transaction can't be matched with this one.")
  end

  it "won't match a transaction on another organization's ledger" do
    elsewhere = create(:canonical_transaction, event: create(:event), amount_cents: 100_00)

    expect { mark(expense, elsewhere) }.to raise_error(described_class::UserError, "That transaction can't be matched with this one.")
  end

  it "won't reuse income that already repaid something" do
    mark(income, expense)
    other_expense = create(:canonical_transaction, event:, amount_cents: -100_00)

    expect { mark(income, other_expense) }.to raise_error(described_class::UserError)
  end

  it "reports a mismatched amount and leaves categories alone" do
    smaller = create(:canonical_transaction, event:, amount_cents: 50_00)

    expect { mark(smaller, expense) }.to raise_error(described_class::UserError, /must match the full amount/)
    expect(Repayment.count).to eq(0)
    expect(expense.reload.category.slug).to eq("food-fun")
  end
end
