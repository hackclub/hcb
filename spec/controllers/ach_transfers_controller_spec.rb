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

    context "when value param is empty" do
      it "doesn't perform a lookup and is valid" do
        get :validate_routing_number, params: { value: "" }

        body = JSON.parse(response.body)
        expect(ColumnService).not_to receive(:get)
        expect(body["valid"]).to be_truthy
      end
    end

    context "when value param is in invalid format" do
      it "is invalid" do
        get :validate_routing_number, params: { value: "INVALID_FORMAT" }

        body = JSON.parse(response.body)

        expect(ColumnService).not_to receive(:get)
        expect(body["valid"]).to be_falsy
        expect(body["hint"]).to eq "Bank not found for this routing number."
      end
    end

    context "when using ColumnService to get instructions" do
      let(:param_value) { "123456789" }
      context "when routing number type is different than aba" do
        it "is invalid" do
          stub_request(:get, "https://api.column.com/institutions/#{param_value}")
            .to_return_json(status: 200, body: { routing_number_type: "not_aba" })

          get :validate_routing_number, params: { value: param_value }
          body = JSON.parse(response.body)

          expect(body["valid"]).to be_falsy
          expect(body["hint"]).to eq "Please enter an ABA routing number."
        end
      end

      context "when ach_eligible is false and routing_number_type is 'aba'" do
        it "is invalid" do
          stub_request(:get, "https://api.column.com/institutions/#{param_value}")
            .to_return_json(status: 200, body: { ach_eligible: false, routing_number_type: "aba" })

          get :validate_routing_number, params: { value: param_value }
          body = JSON.parse(response.body)

          expect(body["valid"]).to be_falsy
          expect(body["hint"]).to eq "This routing number cannot accept ACH transfers."
        end
      end

      context "when ach_eligible is true and routing_number_type is 'aba'" do
        it "is invalid" do
          stub_request(:get, "https://api.column.com/institutions/#{param_value}")
            .to_return_json(status: 200, body: { ach_eligible: true, routing_number_type: "aba", full_name: "full name" })

          get :validate_routing_number, params: { value: param_value }
          body = JSON.parse(response.body)

          expect(body["valid"]).to be_truthy
          expect(body["hint"]).to eq "Full Name"
        end
      end
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

      expect(response).to have_http_status(:unprocessable_entity)
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
