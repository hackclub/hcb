# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::V4::ReceiptsController do
  render_views

  let(:user) { create(:user) }
  let(:event) { create(:event) }

  before do
    create(:organizer_position, user:, event:)
    token = create(:api_token, user:)
    request.headers["Authorization"] = "Bearer #{token.token}"
  end

  describe "#create" do
    it "attaches the receipt to the transaction's ledger item" do
      hcb_code = create(:canonical_pending_transaction, event:).local_hcb_code

      post(:create, params: {
             transaction_id: hcb_code.public_id,
             file: fixture_file_upload("receipt.png", "image/png"),
             format: :json
           })

      expect(response).to have_http_status(:created), response.body
      expect(Receipt.sole).to have_attributes(user:, receiptable: hcb_code.ledger_item, upload_method: "api")
    end

    it "sends a receipt with no transaction to the receipt bin" do
      post(:create, params: { file: fixture_file_upload("receipt.png", "image/png"), format: :json })

      expect(response).to have_http_status(:created), response.body
      expect(Receipt.sole).to have_attributes(user:, receiptable: nil)
    end
  end
end
