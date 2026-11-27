# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::V4::AchTransfersController do
  render_views

  let(:user) { create(:user) }
  let(:event) { create(:event, :with_positive_balance) }

  before do
    create(:organizer_position, user:, event:)
    token = create(:api_token, user:)
    request.headers["Authorization"] = "Bearer #{token.token}"
    allow(ColumnService).to receive(:get).and_return({ "full_name" => "The Bank of Nova Scotia" })
  end

  describe "#create" do
    it "attaches the uploaded receipt to the transfer's ledger item" do
      post(:create, params: {
             event_id: event.public_id,
             format: :json,
             ach_transfer: {
               routing_number: "026002532",
               account_number: "123456789",
               recipient_email: "orpheus@example.com",
               bank_name: "The Bank of Nova Scotia",
               recipient_name: "Orpheus",
               amount_money: "100",
               payment_for: "Snacks",
               file: fixture_file_upload("receipt.png", "image/png"),
             }
           })

      expect(response).to have_http_status(:created), response.body

      hcb_code = event.ach_transfers.sole.local_hcb_code.reload
      expect(hcb_code.ledger_item).to be_present
      expect(hcb_code.ledger_item.receipts.count).to eq(1)
      expect(Receipt.where(receiptable: hcb_code)).to be_empty
    end
  end
end
