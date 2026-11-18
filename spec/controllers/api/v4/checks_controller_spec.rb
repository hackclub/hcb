# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::V4::ChecksController do
  render_views

  let(:user) { create(:user) }
  let(:event) { create(:event, :with_positive_balance) }

  before do
    create(:organizer_position, user:, event:)
    token = create(:api_token, user:)
    request.headers["Authorization"] = "Bearer #{token.token}"
  end

  describe "#create" do
    it "attaches the uploaded receipt to the check's ledger item" do
      post(:create, params: {
             event_id: event.public_id,
             format: :json,
             check: {
               amount_cents: 123_45,
               payment_for: "Snacks",
               memo: "Test memo",
               recipient_name: "Orpheus",
               recipient_email: "orpheus@example.com",
               address_line1: "15 Falls Rd.",
               address_city: "Shelburne",
               address_state: "VT",
               address_zip: "05482",
               file: fixture_file_upload("receipt.png", "image/png"),
             }
           })

      expect(response).to have_http_status(:created), response.body

      hcb_code = event.increase_checks.sole.local_hcb_code.reload
      expect(hcb_code.ledger_item).to be_present
      expect(hcb_code.ledger_item.receipts.count).to eq(1)
      expect(Receipt.where(receiptable: hcb_code)).to be_empty
    end
  end
end
