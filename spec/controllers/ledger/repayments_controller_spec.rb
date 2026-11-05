# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ledger::RepaymentsController, type: :controller do
  include SessionSupport

  let(:event) { create(:event) }
  let(:user) { create(:user) }
  let(:expense) { create(:canonical_transaction, event:, amount_cents: -100_00, memo: "Pizza") }
  let(:income) { create(:canonical_transaction, event:, amount_cents: 100_00, memo: "Venmo from Sam") }

  before { create_session(user, verified: true) }

  context "as a member" do
    before { create(:organizer_position, event:, user:, role: :member) }

    describe "POST #create" do
      it "marks income as a repayment of the chosen expense" do
        post :create, params: { item_id: income.ledger_item.hashid, other_ledger_item_id: expense.ledger_item.hashid }

        expect(flash[:success]).to eq("Marked as a repayment.")
        expect(response).to redirect_to(hcb_code_path(income.ledger_item.hcb_code))
        expect(income.ledger_item.reload.repaying_repayment.repaid_ledger_item).to eq(expense.ledger_item)
      end

      it "marks an expense as repaid by the chosen income" do
        post :create, params: { item_id: expense.ledger_item.hashid, other_ledger_item_id: income.ledger_item.hashid }

        expect(flash[:success]).to eq("Marked as repaid.")
        expect(expense.ledger_item.reload.repayments.sole.repaying_ledger_item).to eq(income.ledger_item)
      end

      it "shows why a match was refused" do
        other_expense = create(:canonical_transaction, event:, amount_cents: -100_00)

        post :create, params: { item_id: expense.ledger_item.hashid, other_ledger_item_id: other_expense.ledger_item.hashid }

        expect(flash[:error]).to eq("That transaction can't be matched with this one.")
        expect(Repayment.count).to eq(0)
      end
    end

    describe "DELETE #destroy" do
      before do
        RepaymentService::Mark.new(ledger_item: income.ledger_item.reload, other_ledger_item_hashid: expense.ledger_item.reload.hashid, created_by: user).run
      end

      it "unmarks from the income" do
        delete :destroy, params: { item_id: income.ledger_item.hashid }

        expect(flash[:success]).to eq("Unmarked the repayment.")
        expect(Repayment.count).to eq(0)
      end

      it "unmarks from the expense" do
        delete :destroy, params: { item_id: expense.ledger_item.hashid }

        expect(Repayment.count).to eq(0)
      end
    end
  end

  context "as a reader" do
    before { create(:organizer_position, event:, user:, role: :reader) }

    it "can't mark a repayment" do
      post :create, params: { item_id: income.ledger_item.hashid, other_ledger_item_id: expense.ledger_item.hashid }

      expect(Repayment.count).to eq(0)
      expect(flash[:error]).to be_present
    end

    it "can't unmark one" do
      RepaymentService::Mark.new(ledger_item: income.ledger_item.reload, other_ledger_item_hashid: expense.ledger_item.reload.hashid, created_by: create(:user)).run

      delete :destroy, params: { item_id: income.ledger_item.hashid }

      expect(Repayment.count).to eq(1)
    end
  end

  context "as someone outside the organization" do
    it "can't mark a repayment" do
      post :create, params: { item_id: income.ledger_item.hashid, other_ledger_item_id: expense.ledger_item.hashid }

      expect(Repayment.count).to eq(0)
    end
  end
end
