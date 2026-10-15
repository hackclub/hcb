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

  def create_transfer(**params)
    post(:create, params: { event_id: source_event.public_id, to_organization_id: destination_event.public_id, name: "Test", amount_cents: 100_00, **params }, as: :json)
  end

  it "makes a plain transfer when no type is given" do
    create_transfer

    expect(response).to have_http_status(:created)
    expect(response.parsed_body["transfer_type"]).to eq("transfer")
    expect(Disbursement.last.source_transaction_category.slug).to eq("internal-transfer")
  end

  it "makes a repayment of a transaction on the destination" do
    expense = create(:canonical_transaction, event: destination_event, amount_cents: -100_00, category_slug: "food-fun")

    create_transfer(transfer_type: "repayment", repaid_transaction_id: expense.local_hcb_code.public_id)

    expect(response).to have_http_status(:created)
    expect(Disbursement.last.repaid_ledger_items).to eq([expense.ledger_item])
  end

  it "won't repay a transaction on an organization the user can't see" do
    # Salary accounts can send to organizations their members aren't on.
    source_event.plan.update!(type: Event::Plan::SalaryAccount.name)
    user.organizer_positions.find_by(event: destination_event).destroy!
    expense = create(:canonical_transaction, event: destination_event, amount_cents: -100_00)

    create_transfer(transfer_type: "repayment", repaid_transaction_id: expense.local_hcb_code.public_id)

    expect(response).to have_http_status(:forbidden)
    expect(Disbursement.count).to eq(0)
  end

  it "rejects an unknown type" do
    create_transfer(transfer_type: "gift")

    expect(response).to have_http_status(:bad_request)
    expect(response.parsed_body["messages"]).to eq(["Choose what kind of transfer this is."])
  end
end
