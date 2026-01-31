# frozen_string_literal: true

require "rails_helper"

RSpec.describe WiresController do
  include SessionSupport

  describe "create" do
    render_views

    def wire_params
      {
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
    end

    it "creates a new wire" do
      user = create(:user)
      event = create(:event, :with_positive_balance)
      create(:organizer_position, user:, event:)

      sign_in(user)

      stub_request(:get, "https://api.column.com/institutions/NOSCCATT")
        .to_return_json(
          status: 200,
          body: { country_code: "CA" }
        )

      post(
        :create,
        params: {
          event_id: event.friendly_id,
          wire: wire_params,
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

    it "requires sudo mode" do
      user = create(:user)
      Flipper.enable(:sudo_mode_2015_07_21, user)
      event = create(:event, :with_positive_balance)
      create(:organizer_position, user:, event:)

      sign_in(user)

      travel(3.hours)

      post(
        :create,
        params: {
          event_id: event.friendly_id,
          wire: {
            **wire_params,
            amount: "500.01",
          }
        }
      )

      expect(event.wires).to be_empty
      expect(response).to have_http_status(:unauthorized)
      expect(response.body).to include("Confirm Access")

      stub_request(:get, "https://api.column.com/institutions/NOSCCATT")
        .to_return_json(
          status: 200,
          body: { country_code: "CA" }
        )

      post(
        :create,
        params: {
          event_id: event.friendly_id,
          wire: {
            **wire_params,
            amount: "500.01",
          },
          _sudo: {
            submit_method: "email",
            login_code: user.login_codes.last.code,
            login_id: user.logins.last.hashid,
          }
        },
      )

      wire = event.wires.sole
      expect(response).to redirect_to(hcb_code_path(wire.local_hcb_code))
      expect(wire.memo).to eq("Test Wire")
      expect(wire.amount_cents).to eq(500_01)
    end
  end
end
