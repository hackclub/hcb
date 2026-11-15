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
    expect(repayment.repaid_ledger_items).to contain_exactly(expense.ledger_item)
    expect(repayment.repaying_ledger_item).to eq(income.ledger_item)
    expect(repayment.allocations.sole.amount_cents).to eq(100_00)
    expect(repayment.created_by).to eq(user)
  end

  it "marks an expense as repaid by income" do
    repayment = mark(expense, income)

    expect(repayment.repaid_ledger_items).to contain_exactly(expense.ledger_item)
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

  describe "with a settled transfer from another organization" do
    let(:sender) { create(:event) }
    let(:transfer) { create(:disbursement, source_event: sender, event:, amount: 100_00) }
    let(:income) { on_transfer_side(create(:canonical_transaction, event:, amount_cents: 100_00), transfer.incoming_disbursement) }
    let(:outgoing) { on_transfer_side(create(:canonical_transaction, event: sender, amount_cents: -100_00, category_slug: "internal-transfer"), transfer.outgoing_disbursement) }

    def on_transfer_side(transaction, side)
      transaction.ledger_item.update_columns(linked_object_type: side.class.polymorphic_name, linked_object_id: side.id)
      transaction
    end

    before { outgoing }

    it "gives the sender's side the expense's category when the marker manages the sender, and puts it back on unmark" do
      create(:organizer_position, user:, event: sender, role: :manager)

      repayment = mark(income, expense)

      expect(income.reload.category.slug).to eq(Repayment::CATEGORY_SLUG)
      expect(outgoing.reload.category.slug).to eq("food-fun")

      RepaymentService::Unmark.new(repayment:).run

      expect(outgoing.reload.category.slug).to eq("internal-transfer")
      expect(expense.reload.category.slug).to eq("food-fun")
    end

    it "leaves the sender's side alone when the marker doesn't manage the sender" do
      create(:organizer_position, user:, event: sender, role: :member)

      repayment = mark(income, expense)

      expect(income.reload.category.slug).to eq(Repayment::CATEGORY_SLUG)
      expect(outgoing.reload.category.slug).to eq("internal-transfer")

      RepaymentService::Unmark.new(repayment:).run

      expect(outgoing.reload.category.slug).to eq("internal-transfer")
    end

    it "won't mark a transfer that was sent as a repayment" do
      transfer.update_columns(transfer_type: "repayment")

      expect { mark(income, expense) }.to raise_error(described_class::UserError, "That transaction can't be matched with this one.")
    end
  end

  it "won't match a different amount, and leaves categories alone" do
    smaller = create(:canonical_transaction, event:, amount_cents: 50_00)

    expect { mark(smaller, expense) }.to raise_error(described_class::UserError, "That transaction can't be matched with this one.")
    expect(Repayment.count).to eq(0)
    expect(expense.reload.category.slug).to eq("food-fun")
  end
end
