# frozen_string_literal: true

require "rails_helper"

RSpec.describe RepaymentService::Mark do
  let(:event) { create(:event) }
  let(:user) { create(:user) }
  let(:expense) { create(:canonical_transaction, event:, amount_cents: -100_00, memo: "Pizza", category_slug: "food-fun") }
  let(:income) { create(:canonical_transaction, event:, amount_cents: 100_00, memo: "Venmo from Sam") }

  # The examples about transfers set up their own roles.
  before { |example| create(:organizer_position, user:, event:, role: :member) unless example.metadata[:own_roles] }

  def mark(from, *to)
    described_class.new(ledger_item: from.ledger_item.reload, other_ledger_item_hashids: to.map { |t| t.ledger_item.reload.hashid }, created_by: user).run
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

  describe "with several expenses" do
    let(:income) { create(:canonical_transaction, event:, amount_cents: 300_00, memo: "Check from Sam") }
    let(:snacks) { create(:canonical_transaction, event:, amount_cents: -200_00, memo: "Snacks", category_slug: "food-fun") }

    it "marks income as repaying expenses that add up to it" do
      repayment = mark(income, expense, snacks)

      expect(repayment.repaid_ledger_items).to contain_exactly(expense.ledger_item, snacks.ledger_item)
      expect(repayment.allocations.map(&:amount_cents)).to contain_exactly(100_00, 200_00)
      expect([expense, snacks, income].map { |t| t.reload.category.slug }).to all(eq(Repayment::CATEGORY_SLUG))
    end

    it "won't mark expenses that don't add up to the income" do
      expect { mark(income, expense) }.to raise_error(described_class::UserError, "The expenses you choose must add up to $300.00.")
      expect(Repayment.count).to eq(0)
      expect(expense.reload.category.slug).to eq("food-fun")
    end

    it "won't mark an expense as repaid by several payments" do
      halves = Array.new(2) { create(:canonical_transaction, event:, amount_cents: 100_00) }

      expect { mark(expense, *halves) }.to raise_error(described_class::UserError)
      expect(Repayment.count).to eq(0)
    end

    it "needs something chosen" do
      expect { mark(income) }.to raise_error(described_class::UserError, "Choose a transaction to match this one with.")
    end
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

  describe "with a settled transfer from another organization", :own_roles do
    let(:sender) { create(:event) }
    let(:transfer) { create(:disbursement, :deposited, source_event: sender, event:, amount: 100_00) }
    let(:income) { on_transfer_side(create(:canonical_transaction, event:, amount_cents: 100_00), transfer.incoming_disbursement) }
    let(:outgoing) { on_transfer_side(create(:canonical_transaction, event: sender, amount_cents: -100_00, category_slug: "internal-transfer"), transfer.outgoing_disbursement) }

    def on_transfer_side(transaction, side)
      transaction.ledger_item.update_columns(linked_object_type: side.class.polymorphic_name, linked_object_id: side.id)
      transaction
    end

    before { outgoing }

    it "gives the sender's side the expense's category" do
      create(:organizer_position, user:, event: sender, role: :manager)
      create(:organizer_position, user:, event:, role: :member)

      mark(income, expense)

      expect(income.reload.category.slug).to eq(Repayment::CATEGORY_SLUG)
      expect(outgoing.reload.category.slug).to eq("food-fun")
    end

    describe "repaying several expenses" do
      let(:transfer) { create(:disbursement, :deposited, source_event: sender, event:, amount: 300_00) }
      let(:income) { on_transfer_side(create(:canonical_transaction, event:, amount_cents: 300_00), transfer.incoming_disbursement) }
      let(:outgoing) { on_transfer_side(create(:canonical_transaction, event: sender, amount_cents: -300_00, category_slug: "internal-transfer"), transfer.outgoing_disbursement) }

      before do
        create(:organizer_position, user:, event: sender, role: :manager)
        create(:organizer_position, user:, event:, role: :member)
      end

      it "gives the sender's side the category the expenses share" do
        mark(income, expense, create(:canonical_transaction, event:, amount_cents: -200_00, category_slug: "food-fun"))

        expect(outgoing.reload.category.slug).to eq("food-fun")
      end

      it "leaves the sender's side without a category when the expenses' differ" do
        mark(income, expense, create(:canonical_transaction, event:, amount_cents: -200_00, category_slug: "benefits"))

        expect(outgoing.reload.category).to be_nil
      end
    end

    it "can be linked by a manager of the sender with read access to the recipient, from the sender's side" do
      create(:organizer_position, user:, event: sender, role: :manager)
      create(:organizer_position, user:, event:, role: :reader)
      other_income = create(:canonical_transaction, event:, amount_cents: 100_00)

      expect(Ledger::ItemPolicy.new(user, income.ledger_item).mark_repayment?).to be(true)
      # Money in that isn't their transfer is for the recipient's members.
      expect(Repayment.match_candidates(expense.ledger_item.reload, user)).to contain_exactly(income.ledger_item)
      expect(Repayment.match_candidates(other_income.ledger_item.reload, user)).to be_empty

      from_sender = Repayment.markable_item(outgoing.ledger_item.reload)
      repayment = described_class.new(ledger_item: from_sender, other_ledger_item_hashids: [expense.ledger_item.reload.hashid], created_by: user).run

      expect(repayment.repaying_ledger_item).to eq(income.ledger_item)
      expect(outgoing.reload.category.slug).to eq("food-fun")
    end

    it "isn't offered to a manager of the recipient who doesn't manage the sender" do
      create(:organizer_position, user:, event:, role: :manager)
      create(:organizer_position, user:, event: sender, role: :member)

      expect(Repayment.match_candidates(expense.ledger_item.reload, user)).to be_empty
      expect(Repayment.match_candidates(income.ledger_item.reload, user)).to be_empty
      expect { mark(income, expense) }.to raise_error(described_class::UserError, "That transaction can't be matched with this one.")
      expect(income.reload.category).to be_nil
      expect(outgoing.reload.category.slug).to eq("internal-transfer")
    end

    it "clears the sender's category when the expense has none" do
      create(:organizer_position, user:, event: sender, role: :manager)
      create(:organizer_position, user:, event:, role: :reader)
      expense.category_mapping.destroy!

      mark(income, expense)

      expect(outgoing.reload.category).to be_nil
    end

    it "won't mark a transfer that hasn't been deposited, since it can still be rejected" do
      create(:organizer_position, user:, event: sender, role: :manager)
      create(:organizer_position, user:, event:, role: :reader)
      transfer.update_columns(aasm_state: "in_transit")

      expect(Repayment.match_candidates(expense.ledger_item.reload, user)).to be_empty
    end

    it "won't mark a transfer that was sent as a repayment" do
      create(:organizer_position, user:, event: sender, role: :manager)
      create(:organizer_position, user:, event:, role: :reader)
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
