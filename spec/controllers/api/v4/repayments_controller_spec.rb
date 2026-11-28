# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::V4::RepaymentsController do
  render_views

  let(:user) { create(:user) }
  let(:event) { create(:event) }
  let(:role) { :member }
  let(:scopes) { nil }
  let(:expense) { create(:canonical_transaction, event:, amount_cents: -100_00, memo: "Pizza") }
  let(:income) { create(:canonical_transaction, event:, amount_cents: 100_00, memo: "Venmo from Sam") }

  before do
    create(:organizer_position, user:, event:, role:)
    token = scopes ? create(:api_token, user:, scopes:) : create(:api_token, user:)
    request.headers["Authorization"] = "Bearer #{token.token}"
  end

  def params_for(tx, **extra)
    { event_id: event.public_id, transaction_id: tx.local_hcb_code.public_id, **extra }
  end

  def mark_repayment
    RepaymentService::Mark.new(ledger_item: income.ledger_item.reload, other_ledger_item_hashid: expense.ledger_item.reload.hashid, created_by: user).run
  end

  describe "#candidates" do
    it "lists transactions of the same amount to match with" do
      income
      create(:canonical_transaction, event:, amount_cents: 50_00)

      get :candidates, params: params_for(expense), as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["data"].pluck("id")).to eq([income.local_hcb_code.public_id])
      expect(response.parsed_body["total_count"]).to eq(1)
    end

    it "is empty once the transaction has been repaid" do
      mark_repayment
      create(:canonical_transaction, event:, amount_cents: 100_00)

      get :candidates, params: params_for(expense), as: :json

      expect(response.parsed_body["data"]).to eq([])
    end
  end

  describe "#create" do
    it "marks income as a repayment of an expense" do
      post :create, params: params_for(income, other_transaction_id: expense.local_hcb_code.public_id), as: :json

      expect(response).to have_http_status(:created)
      expect(response.parsed_body["repayment"]["repays"].sole["id"]).to eq(expense.local_hcb_code.public_id)
      expect(Repayment.sole.created_by).to eq(user)
    end

    it "marks an expense as repaid by income" do
      post :create, params: params_for(expense, other_transaction_id: income.local_hcb_code.public_id), as: :json

      expect(response).to have_http_status(:created)
      expect(response.parsed_body["repayment"]["repaid_by"].sole["id"]).to eq(income.local_hcb_code.public_id)
    end

    it "explains why a match was refused" do
      smaller = create(:canonical_transaction, event:, amount_cents: 50_00)

      post :create, params: params_for(expense, other_transaction_id: smaller.local_hcb_code.public_id), as: :json

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body["messages"]).to eq(["That transaction can't be matched with this one."])
      expect(Repayment.count).to eq(0)
    end

    it "won't match a transaction from another organization" do
      elsewhere = create(:canonical_transaction, event: create(:event), amount_cents: 100_00)

      post :create, params: params_for(expense, other_transaction_id: elsewhere.local_hcb_code.public_id), as: :json

      expect(response).to have_http_status(:bad_request)
      expect(Repayment.count).to eq(0)
    end

    it "404s for a transaction that isn't in the organization" do
      elsewhere = create(:canonical_transaction, event: create(:event), amount_cents: -100_00)

      post :create, params: { event_id: event.public_id, transaction_id: elsewhere.local_hcb_code.public_id, other_transaction_id: income.local_hcb_code.public_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end

    context "as a reader" do
      let(:role) { :reader }

      it "is forbidden" do
        post :create, params: params_for(income, other_transaction_id: expense.local_hcb_code.public_id), as: :json

        expect(response).to have_http_status(:forbidden)
        expect(Repayment.count).to eq(0)
      end
    end

    context "with a restricted token without transactions:write" do
      let(:scopes) { "restricted ledgers:read" }

      it "is forbidden" do
        post :create, params: params_for(income, other_transaction_id: expense.local_hcb_code.public_id), as: :json

        expect(response).to have_http_status(:forbidden)
        expect(Repayment.count).to eq(0)
      end
    end
  end

  describe "a transfer from another organization" do
    let(:role) { :reader }
    let(:sender) { create(:event) }
    let(:transfer) { create(:disbursement, :deposited, source_event: sender, event:, amount: 100_00) }
    let(:incoming) { on_transfer_side(create(:canonical_transaction, event:, amount_cents: 100_00), transfer.incoming_disbursement) }
    let(:outgoing) { on_transfer_side(create(:canonical_transaction, event: sender, amount_cents: -100_00), transfer.outgoing_disbursement) }

    def on_transfer_side(transaction, side)
      transaction.ledger_item.update_columns(linked_object_type: side.class.polymorphic_name, linked_object_id: side.id)
      transaction
    end

    before do
      create(:organizer_position, user:, event: sender, role: :manager)
      incoming
    end

    it "can be marked as a repayment by the sender, from their side" do
      post :create, params: { event_id: sender.public_id, transaction_id: outgoing.local_hcb_code.public_id, other_transaction_id: expense.local_hcb_code.public_id }, as: :json

      expect(response).to have_http_status(:created)
      expect(response.parsed_body["repayment"]["repays"].sole["id"]).to eq(expense.local_hcb_code.public_id)
      expect(Repayment.sole.repaying_ledger_item).to eq(incoming.ledger_item)
    end
  end
end
