# frozen_string_literal: true

require "rails_helper"

RSpec.describe WiresController do
  include SessionSupport

  describe "create" do
    it "creates a new wire" do
      user = create(:user)
      event = create(:event, :with_positive_balance)
      create(:organizer_position, user:, event:)

      sign_in(user)

      post(
        :create,
        params: {
          event_id: event.friendly_id,
          wire: {
            memo: "Test Wire",
            amount: "500",
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
          }
        }
      )

      wire = event.wires.sole
      expect(response).to redirect_to(hcb_code_path(wire.local_hcb_code))

      expect(wire.memo).to eq("Test Wire")
      expect(wire.amount_cents).to eq(500_00)
      expect(wire.payment_for).to eq("Snacks")
      expect(wire.recipient_name).to eq("Orpheus")
      expect(wire.recipient_email).to eq("orpheus@example.com")
      expect(wire.account_number).to eq("123456789")
      expect(wire.bic_code).to eq("NOSCCATT")
      expect(wire.recipient_country).to eq("CA")
      expect(wire.currency).to eq("USD")
      expect(wire.address_line1).to eq("1 Main Street")
      expect(wire.address_city).to eq("Ottawa")
      expect(wire.address_postal_code).to eq("K1A 0A6")
      expect(wire.address_state).to eq("Ontario")
    end
  end
end
