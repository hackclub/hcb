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

    describe "GET #candidates" do
      render_views

      it "lists unused income of the same amount for an expense" do
        income
        smaller = create(:canonical_transaction, event:, amount_cents: 50_00)

        get :candidates, params: { item_id: expense.ledger_item.hashid }

        expect(response).to be_successful
        expect(response.body).to include(%(value="#{income.ledger_item.hashid}"))
        expect(response.body).not_to include(%(value="#{smaller.ledger_item.hashid}"))
      end

      it "lists unrepaid expenses of the same amount for income" do
        expense

        get :candidates, params: { item_id: income.ledger_item.hashid }

        expect(response.body).to include(%(value="#{expense.ledger_item.hashid}"))
      end

      it "renders each candidate as a ledger row with a Choose button" do
        income

        get :candidates, params: { item_id: expense.ledger_item.hashid }

        # The memo links to the candidate's popover like a ledger row, and the row ends in the Choose button.
        expect(response.body).to include(ledger_item_path(income.ledger_item))
        expect(response.body).to include(%(id="#{ActionView::RecordIdentifier.dom_id(income.ledger_item, :badges)}"))
        expect(response.body).to include(%(aria-label="Choose #{income.ledger_item.memo}, $100.00 on #{income.ledger_item.datetime.strftime("%b %-d, %Y")}"))
      end

      it "doesn't make candidates drop targets for receipts" do
        income

        get :candidates, params: { item_id: expense.ledger_item.hashid }

        expect(response.body).not_to include("file-drop")
      end

      it "shows an empty state when nothing matches" do
        get :candidates, params: { item_id: expense.ledger_item.hashid }

        expect(response.body).to include("No transactions left to match")
      end
    end

    describe "POST #create" do
      it "marks income as a repayment of the chosen expense" do
        post :create, params: { item_id: income.ledger_item.hashid, other_ledger_item_id: expense.ledger_item.hashid }

        expect(flash[:success]).to eq("Marked as a repayment.")
        expect(response).to redirect_to(hcb_code_path(income.ledger_item.hcb_code))
        expect(income.ledger_item.reload.repaying_repayment.repaid_ledger_items).to contain_exactly(expense.ledger_item)
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
  end

  context "as a reader" do
    before { create(:organizer_position, event:, user:, role: :reader) }

    it "can't mark a repayment" do
      post :create, params: { item_id: income.ledger_item.hashid, other_ledger_item_id: expense.ledger_item.hashid }

      expect(Repayment.count).to eq(0)
      expect(flash[:error]).to be_present
    end
  end

  context "as someone outside the organization" do
    it "can't mark a repayment" do
      post :create, params: { item_id: income.ledger_item.hashid, other_ledger_item_id: expense.ledger_item.hashid }

      expect(Repayment.count).to eq(0)
    end
  end

  context "as a manager of another organization viewing a transparent one" do
    render_views

    let(:event) { create(:event, is_public: true) }

    before { create(:organizer_position, event: create(:event), user:, role: :manager) }

    it "doesn't show the amount of a transaction they can't link" do
      item = create(:canonical_transaction, event:, amount_cents: 123_45).ledger_item

      get :candidates, params: { item_id: item.hashid }

      expect(response).to be_successful
      expect(response.body).not_to include("123.45")
    end
  end
end
