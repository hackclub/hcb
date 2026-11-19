# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::V4::WiresController do
  render_views

  let(:user) { create(:user) }
  let(:event) { create(:event, :with_positive_balance) }

  before do
    create(:organizer_position, user:, event:)
    token = create(:api_token, user:)
    request.headers["Authorization"] = "Bearer #{token.token}"
    stub_request(:get, "https://api.column.com/institutions/NOSCCATT")
      .to_return_json(status: 200, body: { country_code: "CA" })
  end

  describe "#create" do
    it "attaches the uploaded receipt to the wire's ledger item" do
      post(:create, params: {
             event_id: event.public_id,
             format: :json,
             wire: {
               memo: "Test Wire",
               amount_cents: 500_00,
               payment_for: "Snacks",
               recipient_name: "Orpheus",
               recipient_email: "orpheus@example.com",
               account_number: "123456789",
               bic_code: "NOSCCATT",
               recipient_country: "CA",
               currency: "USD",
               address_line1: "1 Main Street",
               address_city: "Ottawa",
               address_postal_code: "K1A 0A6",
               address_state: "Ontario",
               file: fixture_file_upload("receipt.png", "image/png"),
             }
           })

      expect(response).to have_http_status(:created), response.body

      hcb_code = event.wires.sole.local_hcb_code.reload
      expect(hcb_code.ledger_item).to be_present
      expect(hcb_code.ledger_item.receipts.count).to eq(1)
      expect(Receipt.where(receiptable: hcb_code)).to be_empty
    end
  end
end
