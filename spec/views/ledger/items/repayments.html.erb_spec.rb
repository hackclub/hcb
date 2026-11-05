# frozen_string_literal: true

require "rails_helper"

RSpec.describe "ledger/items/_repayments" do
  let(:event) { create(:event) }
  let(:expense) { create(:canonical_transaction, event:, amount_cents: -100_00) }
  let(:income) { create(:canonical_transaction, event:, amount_cents: 100_00) }
  let(:can_unmark) { true }

  # View specs have no signed-in user for Pundit's `policy` helper.
  before do
    without_partial_double_verification do
      allow(view).to receive(:policy).and_return(instance_double(Ledger::ItemPolicy, show?: true, unmark_repayment?: can_unmark))
    end
  end

  context "when the repayment was marked between two transactions on the ledger" do
    before do
      RepaymentService::Mark.new(ledger_item: income.ledger_item.reload, other_ledger_item_hashid: expense.ledger_item.reload.hashid, created_by: create(:user)).run
    end

    it "links the expense to the income that repaid it" do
      render partial: "ledger/items/repayments", locals: { ledger_item: expense.ledger_item.reload }

      expect(rendered).to include("Repaid by")
      expect(rendered).to include(ledger_item_path(income.ledger_item))
    end

    it "links the income to the expense it repays" do
      render partial: "ledger/items/repayments", locals: { ledger_item: income.ledger_item.reload }

      expect(rendered).to include("Repays")
      expect(rendered).to include(ledger_item_path(expense.ledger_item))
    end

    it "offers to unmark it" do
      render partial: "ledger/items/repayments", locals: { ledger_item: expense.ledger_item.reload }

      expect(rendered).to include("Unmark")
      expect(rendered).to include(%(action="#{ledger_item_repayment_path(expense.ledger_item)}"))
    end

    context "for someone who can't unmark it" do
      let(:can_unmark) { false }

      it "doesn't offer to" do
        render partial: "ledger/items/repayments", locals: { ledger_item: expense.ledger_item.reload }

        expect(rendered).not_to include("Unmark")
      end
    end
  end

  it "doesn't offer to unmark a repayment transfer" do
    Repayment.new(disbursement: create(:disbursement, event:), repaid_ledger_item: expense.ledger_item, amount_cents: 100_00).save!(validate: false)

    render partial: "ledger/items/repayments", locals: { ledger_item: expense.ledger_item.reload }

    expect(rendered).not_to include("Unmark")
  end
end
