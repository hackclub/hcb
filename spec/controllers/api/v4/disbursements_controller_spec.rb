# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::V4::DisbursementsController do
  render_views

  let(:user) { create(:user) }
  let(:source_event) { create(:event, :with_positive_balance) }
  let(:destination_event) { create(:event) }

  before do
    create(:organizer_position, user:, event: source_event)
    create(:organizer_position, user:, event: destination_event)
    token = create(:api_token, user:)
    request.headers["Authorization"] = "Bearer #{token.token}"
  end

  describe "#create" do
    it "makes an internal transfer" do
      post(:create, params: { event_id: source_event.public_id, to_organization_id: destination_event.public_id, name: "Test", amount_cents: 100_00 }, as: :json)

      expect(response).to have_http_status(:created)
      disbursement = Disbursement.last
      expect(disbursement.transfer_type).to eq("transfer")
      expect(disbursement.source_transaction_category.slug).to eq("internal-transfer")
    end

    context "repaying a transaction" do
      let(:expense) { create(:canonical_transaction, event: destination_event, amount_cents: -100_00, memo: "Pizza", category_slug: "food-fun") }

      def repay(**params)
        post(:create, params: { event_id: source_event.public_id, to_organization_id: destination_event.public_id, name: "Repaying pizza", amount_cents: 100_00, transfer_type: "repayment", **params }, as: :json)
      end

      it "repays the transaction and categorizes both sides" do
        repay(repaid_transaction_id: expense.local_hcb_code.public_id)

        expect(response).to have_http_status(:created)
        expect(response.parsed_body["transfer_type"]).to eq("repayment")
        expect(response.parsed_body["repays"]).to eq([{ "id" => expense.local_hcb_code.public_id }])

        disbursement = Disbursement.last
        expect(disbursement.repaid_ledger_items).to eq([expense.ledger_item])
        expect(disbursement.source_transaction_category.slug).to eq("food-fun")
        expect(expense.reload.category.slug).to eq(Repayment::CATEGORY_SLUG)
      end

      it "requires the transaction being repaid" do
        repay

        expect(response).to have_http_status(:bad_request)
        expect(response.parsed_body["messages"]).to eq(["Choose the transaction you're repaying."])
        expect(Disbursement.count).to eq(0)
      end

      it "won't repay a transaction that's already been repaid" do
        income = create(:canonical_transaction, event: destination_event, amount_cents: 100_00)
        RepaymentService::Mark.new(ledger_item: income.ledger_item.reload, other_ledger_item_hashid: expense.ledger_item.reload.hashid, created_by: user).run

        repay(repaid_transaction_id: expense.local_hcb_code.public_id)

        expect(response).to have_http_status(:bad_request)
        expect(Disbursement.count).to eq(0)
      end

      it "rejects an unknown transfer type" do
        repay(transfer_type: "gift", repaid_transaction_id: expense.local_hcb_code.public_id)

        expect(response).to have_http_status(:bad_request)
        expect(Disbursement.count).to eq(0)
      end

      it "is forbidden without access to the recipient's transactions" do
        private_event = create(:event, is_public: false)
        private_expense = create(:canonical_transaction, event: private_event, amount_cents: -100_00)

        post(:create, params: { event_id: source_event.public_id, to_organization_id: private_event.public_id, name: "Repaying", amount_cents: 100_00, transfer_type: "repayment", repaid_transaction_id: private_expense.local_hcb_code.public_id }, as: :json)

        expect(response).to have_http_status(:forbidden)
        expect(Disbursement.count).to eq(0)
      end
    end

    it "only fronts transfers into organizations the user manages" do
      user = create(:user)
      source_event = create(:event, :with_positive_balance, organizers: [user], plan_type: Event::Plan::HackClubAffiliate)
      own_event = create(:event, organizers: [user])
      public_event = create(:event)

      token = create(:api_token, user:)
      request.headers["Authorization"] = "Bearer #{token.token}"

      post(:create, params: { event_id: source_event.public_id, to_organization_id: own_event.public_id, name: "Own", amount_cents: 40_00 }, as: :json)
      expect(response).to have_http_status(:created)
      expect(Disbursement.last.canonical_pending_transactions.map(&:fronted)).to eq([true, true])

      post(:create, params: { event_id: source_event.public_id, to_organization_id: public_event.public_id, name: "Public", amount_cents: 40_00 }, as: :json)
      expect(response).to have_http_status(:created)
      expect(Disbursement.last.canonical_pending_transactions.map(&:fronted)).to eq([false, false])
    end
  end
end
