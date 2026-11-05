# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::V4::TransactionsController do
  render_views

  let(:user) { create(:user) }
  let(:event) { create(:event) }
  let(:expense) { create(:canonical_transaction, event:, amount_cents: -100_00, memo: "Pizza") }
  let(:income) { create(:canonical_transaction, event:, amount_cents: 100_00, memo: "Venmo from Sam") }

  before do
    create(:organizer_position, user:, event:)
    token = create(:api_token, user:)
    request.headers["Authorization"] = "Bearer #{token.token}"
  end

  def mark_repayment
    RepaymentService::Mark.new(ledger_item: income.ledger_item.reload, other_ledger_item_hashid: expense.ledger_item.reload.hashid, created_by: user).run
  end

  describe "repayments" do
    it "shows what repaid an expense" do
      mark_repayment

      get :show, params: { id: expense.local_hcb_code.public_id }, as: :json

      expect(response.parsed_body["repayment"]).to eq(
        "repaid_by"  => [{ "id" => income.local_hcb_code.public_id, "transfer" => false }],
        "repays"     => [],
        "can_unmark" => true
      )
    end

    it "shows what income repays" do
      mark_repayment

      get :show, params: { id: income.local_hcb_code.public_id }, as: :json

      expect(response.parsed_body["repayment"]["repays"]).to eq([{ "id" => expense.local_hcb_code.public_id, "transfer" => false }])
    end

    it "is left out for transactions that aren't part of a repayment" do
      get :show, params: { id: expense.local_hcb_code.public_id }, as: :json

      expect(response.parsed_body).not_to have_key("repayment")
    end

    it "can't be unmarked when it's a transfer" do
      Repayment.new(disbursement: create(:disbursement, event:), repaid_ledger_item: expense.ledger_item, repaying_ledger_item: nil, amount_cents: 100_00).save!(validate: false)
      allow_any_instance_of(Ledger::Item).to receive(:repaid_by_items).and_return([income.ledger_item.reload])

      get :show, params: { id: expense.local_hcb_code.public_id }, as: :json

      expect(response.parsed_body["repayment"]["can_unmark"]).to be(false)
    end

    it "hides the other side when it's in an organization the user can't see" do
      elsewhere = create(:canonical_transaction, event: create(:event, is_public: false), amount_cents: 100_00)
      allow_any_instance_of(Ledger::Item).to receive(:repaid_by_items).and_return([elsewhere.ledger_item.reload])

      get :show, params: { id: expense.local_hcb_code.public_id }, as: :json

      expect(response.parsed_body["repayment"]["repaid_by"]).to eq([{ "id" => nil, "transfer" => false }])
    end

    it "is included in the transaction list" do
      mark_repayment

      get :index, params: { id: event.public_id }, as: :json

      by_id = response.parsed_body["data"].index_by { |tx| tx["id"] }
      expect(by_id[expense.local_hcb_code.public_id]["repayment"]["repaid_by"].sole["id"]).to eq(income.local_hcb_code.public_id)
      expect(by_id[income.local_hcb_code.public_id]["repayment"]["repays"].sole["id"]).to eq(expense.local_hcb_code.public_id)
    end
  end
end
