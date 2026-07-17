# frozen_string_literal: true

require "rails_helper"

RSpec.describe WiresController do
  include SessionSupport

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

  describe "create" do
    render_views

    it "creates a new wire" do
      user = create(:user)
      event = create(:event, :with_positive_balance)
      create(:organizer_position, user:, event:)

      create_session(user, verified: true)

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

      create_session(user, verified: true)

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

  describe "update" do
    def create_wire
      user = create(:user)
      event = create(:event, :with_positive_balance)
      create(:organizer_position, user:, event:)

      stub_request(:get, "https://api.column.com/institutions/NOSCCATT")
        .to_return_json(
          status: 200,
          body: { country_code: "CA" }
        )

      event.wires.create!(user:, **wire_params)
    end

    it "allows admins to edit the currency and amount" do
      wire = create_wire
      expect(wire.canonical_pending_transaction.amount_cents).to eq(-500_00)

      admin = create(:user, :make_admin)
      create_session(admin, verified: true)

      patch(
        :update,
        params: {
          id: wire.id,
          wire: {
            currency: "EUR",
            amount: "600",
          }
        }
      )

      expect(response).to redirect_to(wire_process_admin_path(wire))

      wire.reload
      expect(wire.currency).to eq("EUR")
      expect(wire.amount_cents).to eq(600_00)
      expect(wire.canonical_pending_transaction.reload.amount_cents).to eq(-MoneyService.convert_to_usd(600_00, "EUR"))
    end

    it "is not allowed for non-admins" do
      wire = create_wire

      create_session(wire.user, verified: true)

      patch(
        :update,
        params: {
          id: wire.id,
          wire: { amount: "600" }
        }
      )

      expect(flash[:error]).to eq("You are not authorized to perform this action.")
      expect(wire.reload.amount_cents).to eq(500_00)
    end
  end
end
