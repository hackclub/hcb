# frozen_string_literal: true

require "rails_helper"

RSpec.describe RepaymentService::Unmark do
  let(:event) { create(:event) }
  let(:expense) { create(:canonical_transaction, event:, amount_cents: -100_00, category_slug: "food-fun") }
  let(:income) { create(:canonical_transaction, event:, amount_cents: 100_00) }

  it "removes the repayment and restores both categories" do
    repayment = RepaymentService::Mark.new(ledger_item: income.ledger_item.reload, other_ledger_item_hashid: expense.ledger_item.reload.hashid, created_by: create(:user)).run

    described_class.new(repayment:).run

    expect(Repayment.exists?(repayment.id)).to be(false)
    expect(expense.reload.category.slug).to eq("food-fun")
    expect(income.reload.category).to be_nil
  end

  it "leaves repayment transfers to be undone by rejecting them" do
    repayment = Repayment.new(disbursement: create(:disbursement, event:), repaid_ledger_item: expense.ledger_item, amount_cents: 100_00)
    repayment.save!(validate: false)

    expect { described_class.new(repayment:).run }.to raise_error(ArgumentError)
    expect(Repayment.exists?(repayment.id)).to be(true)
  end
end
