# frozen_string_literal: true

require "rails_helper"

describe AchTransfersController do
  include SessionSupport

  describe "show" do
    it "redirects to hcb code" do
      event = create(:event)
      create(:canonical_pending_transaction, amount_cents: 1000, event:, fronted: true)
      ach_transfer = create(:ach_transfer, event:)
      get :show, params: { id: ach_transfer.id }
      expect(response).to redirect_to(hcb_code_path(ach_transfer.local_hcb_code.hashid))
    end
  end

  describe "validate_routing_number" do
    before do
      user = create(:user)
      sign_in(user)
    end

    it "doesn't perform a lookup when routing number is invalid" do
      expect(ColumnService).not_to receive(:get)

      get :validate_routing_number, params: { value: "not a routing number" }
    end

    it "handles unknown routing numbers" do
      stub_request(:get, "https://api.column.com/institutions/123456789")
        .to_return(status: 400)

      get :validate_routing_number, params: { value: "123456789" }

      expect(response.parsed_body).to eq({ "valid" => false, "hint" => "Bank not found for this routing number." })
    end

    it "returns bank name" do
      stub_request(:get, "https://api.column.com/institutions/083000137")
        .to_return_json(
          status: 200,
          body: {
            routing_number_type: "aba",
            ach_eligible: true,
            full_name: "JPMORGAN CHASE BANK, NA",
          }
        )

      get :validate_routing_number, params: { value: "083000137" }

      expect(response.parsed_body).to eq({ "valid" => true, "hint" => "Jpmorgan Chase Bank, Na" })
    end
  end

  describe "create" do
    render_views

    def ach_transfer_params
      {
        routing_number: "026002532",
        account_number: "123456789",
        recipient_email: "orpheus@example.com",
        bank_name: "The Bank of Nova Scotia",
        recipient_name: "Orpheus",
        amount_money: "100",
        payment_for: "Snacks",
        send_email_notification: false,
        invoiced_at: "2025-01-01"
      }
    end

    it "creates an ACH transfer" do
      user = create(:user)
      event = create(:event, :with_positive_balance)
      create(:organizer_position, user:, event:)

      sign_in(user)

      post(
        :create,
        params: {
          event_id: event.friendly_id,
          ach_transfer: ach_transfer_params,
        }
      )

      expect(response).to redirect_to(event_transfers_path(event))

      ach_transfer = event.ach_transfers.sole
      expect(ach_transfer).to be_pending
      expect(ach_transfer.creator).to eq(user)
      expect(ach_transfer.routing_number).to eq("026002532")
      expect(ach_transfer.account_number).to eq("123456789")
      expect(ach_transfer.bank_name).to eq("The Bank of Nova Scotia")
      expect(ach_transfer.recipient_name).to eq("Orpheus")
      expect(ach_transfer.recipient_email).to eq("orpheus@example.com")
      expect(ach_transfer.amount).to eq(100_00)
      expect(ach_transfer.payment_for).to eq("Snacks")
      expect(ach_transfer.send_email_notification).to eq(false)
      expect(ach_transfer.invoiced_at).to eq(Date.new(2025, 1, 1))
    end

    it "requires sudo mode if the amount is greater than 500" do
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
          ach_transfer: {
            **ach_transfer_params,
            amount_money: "500.01",
          }
        }
      )

      expect(response).to have_http_status(:unauthorized)
      expect(event.ach_transfers).to be_empty
      expect(response.body).to include("Confirm Access")

      post(
        :create,
        params: {
          event_id: event.friendly_id,
          ach_transfer: {
            **ach_transfer_params,
            amount_money: "500.01",
          },
          _sudo: {
            submit_method: "email",
            login_code: user.login_codes.last.code,
            login_id: user.logins.last.hashid,
          }
        }
      )

      expect(response).to redirect_to(event_transfers_path(event))
      ach_transfer = event.ach_transfers.sole
      expect(ach_transfer.payment_for).to eq("Snacks")
      expect(ach_transfer.amount).to eq(500_01)
    end
  end
end
