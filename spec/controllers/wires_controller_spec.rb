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

  describe "send_wire" do
    it "charges the fee as a disbursement to HCB Operations with a comment linking to the wire" do
      admin = create(:user, :make_admin)
      create(:event, id: EventMappingEngine::EventIds::HACK_CLUB_BANK)
      event = create(:event, :with_positive_balance)
      stub_request(:get, "https://api.column.com/institutions/DEUTDEDB")
        .to_return_json(status: 200, body: { country_code: "DE" })
      wire = create(:wire, :pending, event:)

      allow_any_instance_of(GovernanceService::Admin::Transfer::Approval).to receive(:ensure_may_approve!)
      allow_any_instance_of(Wire).to receive(:send_wire!)

      create_session(admin, verified: true)

      post(:send_wire, params: { id: wire.id, charge_fee: "1" })

      expect(response).to redirect_to(wire_process_admin_path(wire))
      expect(flash[:success]).to eq("Thanks for approving that wire.")

      disbursement = Disbursement.sole
      expect(disbursement.source_event).to eq(event)
      expect(disbursement.destination_event.id).to eq(EventMappingEngine::EventIds::HACK_CLUB_BANK)
      expect(disbursement.amount).to eq(25_00)
      expect(disbursement.transfer_type).to eq("transfer")
      expect(disbursement.source_transaction_category.slug).to eq("internal-transfer")
      expect(disbursement.destination_transaction_category.slug).to eq("internal-transfer")

      comment = disbursement.comments.sole
      expect(comment.user).to eq(admin)
      expect(comment.content).to include(hcb_code_url(wire.local_hcb_code))
    end
  end
end
