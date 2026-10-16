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

  it "makes an internal transfer" do
    post(:create, params: { event_id: source_event.public_id, to_organization_id: destination_event.public_id, name: "Test", amount_cents: 100_00 }, as: :json)

    expect(response).to have_http_status(:created)
    disbursement = Disbursement.last
    expect(disbursement.transfer_type).to eq("transfer")
    expect(disbursement.source_transaction_category.slug).to eq("internal-transfer")
  end
end
